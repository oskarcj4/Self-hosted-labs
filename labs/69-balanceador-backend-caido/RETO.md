# Balanceador con backends enfermos

> Operaciones · nginx upstream · reintentos · health checks pasivos · timeouts

## Escenario

`lb-01` reparte la tienda entre `app1`, `app2` y `app3`. Ahora mismo una de
cada tres peticiones da **503** (app2) y otra tarda **8 s** (app3).
Desarrollo ya está con ellos, pero tardarán horas. Lee
`~/ticket/INC-6909.txt`.

Mientras tanto, el balanceador tiene que proteger a los clientes.

## Objetivos

1. Todas las peticiones a `http://lb-01/` dan **200** en **menos de 3 s**,
   aunque app2 y app3 sigan mal.
2. **No** saques app2 ni app3 del upstream (ni `down` ni `backup`): cuando se
   arreglen, deben volver a recibir tráfico **solos en 30 s como mucho**.
3. Los `POST` no se reintentan en otro backend.

## Comandos que te pueden servir

```bash
for i in $(seq 9); do curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' http://127.0.0.1/; done
curl -s -D- http://127.0.0.1/ -o /dev/null | grep -i x-backend
curl -s http://10.76.69.22:8080/ ; time curl -s http://10.76.69.23:8080/
sudo tail -f /var/log/nginx/error.log
sudo nginx -t && sudo systemctl reload nginx
```

Directivas a investigar: `proxy_next_upstream`, `proxy_connect_timeout`,
`proxy_read_timeout`, `proxy_next_upstream_tries`, y en `server` del upstream,
`max_fails` y `fail_timeout`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
