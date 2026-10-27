# Resolución guiada · Balanceador con backends enfermos

:::piensa Antes de tocar nada
app2 da 503 y app3 tarda 8 s. El balanceador tiene que **proteger al cliente**
sin esconder los backends: nada de `down` ni `backup`, porque deben volver solos
al arreglarse. Las piezas: reintento a otro backend (`proxy_next_upstream`),
timeouts cortos, y health checks pasivos (`max_fails`/`fail_timeout`). Y los
`POST` **no** se reintentan: podrían duplicar.
:::

## Paso 1 · Mide el problema

```bash
for i in $(seq 9); do curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' http://127.0.0.1/; done
# 200 0.002s / 503 0.003s / 200 8.006s / ...
```

Round robin puro: nginx entrega el 503 de app2 y espera los 8 s de app3.

## Paso 2 · La configuración

**Pregúntate:** ¿cómo reintento rápido en otro backend y aparto al que falla,
sin sacarlo del upstream?

:::pista La config
```nginx
upstream tienda {
    zone tienda 64k;                     # estado de fallos compartido entre workers
    server 10.76.69.21:8080 max_fails=1 fail_timeout=15s;   # app1
    server 10.76.69.22:8080 max_fails=1 fail_timeout=15s;   # app2
    server 10.76.69.23:8080 max_fails=1 fail_timeout=15s;   # app3
}
server {
    listen 80 default_server;
    location / {
        proxy_pass http://tienda;
        proxy_set_header Host $host;
        proxy_connect_timeout 1s;
        proxy_read_timeout 2s;
        proxy_next_upstream error timeout http_502 http_503 http_504;   # sin 'non_idempotent' -> POST no se repite
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 3s;
    }
}
```
```bash
sudo nginx -t && sudo systemctl reload nginx
```
- **app2 (503)**: nginx descarta, reintenta en otro y marca a app2 fallido
  (`fail_timeout` 15 s); luego le prueba una petición y vuelve al reparto.
- **app3 (lento)**: a los 2 s salta `proxy_read_timeout`, reintenta (~2 s total)
  y aparta app3 15 s.
- **`zone`**: todos los workers comparten qué backend está marcado.
:::

## Paso 3 · Por qué NO reintentar POST

Si un `POST /pedido` a app3 hace timeout, quizá app3 **sí** grabó el pedido y
sólo tardó. Reintentar en app1 lo duplicaría. nginx (≥1.9.13) no reintenta
métodos no idempotentes salvo que pongas `non_idempotent`. El viejo
`proxy_next_upstream off` lo evitaba, pero desactivaba **todo** reintento.

## Paso 4 · Verifica

```bash
for i in $(seq 9); do curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' http://127.0.0.1/; done  # todo 200 <3s
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Sin health checks, el balanceador reparte también a los backends rotos.**
- **Pasivos** (`max_fails`/`fail_timeout`): nginx aprende de respuestas reales.
  **Activos** (sondas): nginx Plus, HAProxy, Envoy, balanceadores cloud.
- **Reintentos acotados** (`tries`, `timeout`) y sólo si es idempotente.
- **No apartes backends a mano** "para salir del paso": luego nadie los
  reincorpora.

## Si te atascas

- Sigue saliendo 503 → faltó `http_503` en `proxy_next_upstream`, o `tries<2`.
- Sigue tardando 8 s → `proxy_read_timeout` sigue por defecto (60 s); ponlo 2s.
- Timeouts globales rompen una ruta lenta legítima → dale su propio `location`
  con timeout largo (lab 62).
