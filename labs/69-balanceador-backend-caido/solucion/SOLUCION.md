# Solución — Balanceador con backends enfermos

## 1. Mide

```bash
for i in $(seq 9); do curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' http://127.0.0.1/; done
# 200 0.002s
# 503 0.003s
# 200 8.006s
# ...
```

Round robin puro. Con `proxy_next_upstream off`, nginx entrega al cliente el
503 de app2 y espera los 8 s de app3 (el `proxy_read_timeout` por defecto es
de 60 s).

## 2. La configuración

```nginx
upstream tienda {
    zone tienda 64k;                     # estado de fallos compartido entre workers
    server 10.76.69.21:8080 max_fails=1 fail_timeout=15s;   # app1
    server 10.76.69.22:8080 max_fails=1 fail_timeout=15s;   # app2
    server 10.76.69.23:8080 max_fails=1 fail_timeout=15s;   # app3
}

server {
    listen 80 default_server;
    server_name tienda.local;

    location / {
        proxy_pass http://tienda;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_connect_timeout 1s;
        proxy_read_timeout 2s;
        # Reintenta en otro backend si hay error, timeout o 502/503/504...
        # ...pero sólo peticiones idempotentes: sin 'non_idempotent', un POST nunca se repite.
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 3s;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Qué pasa ahora:

- **app2 (503):** nginx descarta la respuesta, reintenta en otro backend y
  marca a app2 como fallido. Durante `fail_timeout` (15 s) no le manda nada.
  Después le manda una petición de prueba: si va bien, vuelve al reparto.
- **app3 (lento):** a los 2 s salta `proxy_read_timeout`, nginx reintenta en
  otro backend (≈2 s en total) y aparta a app3 15 s.
- `zone` hace que todos los workers compartan qué backend está marcado. Sin
  ella, cada worker lo descubre por su cuenta (más peticiones lentas).

## 3. Por qué no reintentar POST

Si un `POST /pedido` llega a app3 y hace timeout, quizá app3 **sí** grabó el
pedido y sólo tardó en responder. Reintentarlo en app1 duplicaría el pedido.
nginx (≥1.9.13) no reintenta métodos no idempotentes salvo que pongas
`non_idempotent`. Esa es la buena intención del comentario de 2023:
`proxy_next_upstream off` lo conseguía, pero lo desactivaba todo.

## 4. Elige bien los timeouts

`proxy_read_timeout 2s` sirve para esta tienda. En una ruta que de verdad
tarda (un informe, una subida), ponle su propio `location` con un timeout más
largo (como en el lab 62).

## Lecciones

- Un balanceador sin health checks reparte también hacia los backends rotos.
- Health checks **pasivos** (`max_fails`/`fail_timeout`): nginx aprende de
  las respuestas reales. Los **activos** (sondas periódicas) existen en nginx
  Plus, HAProxy, Envoy y los balanceadores cloud.
- Reintentos sí, pero acotados (`tries`, `timeout`) y sólo si la petición es
  idempotente.
- No apartes backends a mano "para salir del paso": luego nadie se acuerda de
  volver a meterlos.
