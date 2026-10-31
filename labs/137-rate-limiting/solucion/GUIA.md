# Resolución guiada · Lab 137

:::piensa Antes de tocar nada
Mide antes de cambiar. Si no tienes un "antes", no puedes demostrar que el
límite funciona. Y el límite tiene que frenar al bot sin molestar al usuario
normal ni a los ficheros estáticos.
:::

## Paso 1 · ¿Quién machaca el login?

:::pista Cómo comprobarlo
```bash
sudo awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```
Escribe `ip_bot=` en `~/limite.txt`.
:::

## Paso 2 · Mide sin límite

:::pista Cómo hacerlo
```bash
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-antes.txt
grep -A4 'Status code' ~/hey-antes.txt
```
Todo 401: el backend contesta a todos, por rápido que pidan.
:::

## Paso 3 · Define las zonas

**Pregúntate:** las zonas se declaran una vez (contexto `http`) y se usan donde quieras. ¿Qué clave identifica a cada cliente?

:::pista Cómo hacerlo
```bash
sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=login:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conexiones:10m;
limit_req_status  429;
limit_conn_status 429;
N
```
:::

## Paso 4 · Aplícalas sólo al login

:::pista Cómo hacerlo
```nginx
location /api/login {
    limit_req zone=login burst=10 nodelay;
    limit_conn conexiones 10;
    proxy_pass http://127.0.0.1:9137;
}
```
```bash
sudo nginx -t && sudo systemctl reload nginx
```
`burst=10 nodelay`: admite una ráfaga de 10 al momento; a partir de ahí, 5 por segundo.
:::

## Paso 5 · Mide otra vez

:::pista Cómo comprobarlo
```bash
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-despues.txt
grep -A4 'Status code' ~/hey-despues.txt
sudo tail -f /var/log/nginx/access.log | grep ' 429 '
```
:::

## Cómo actuar en una situación así

- **Límites distintos por ruta**: el login es caro y atacable; los estáticos no.
- **Detrás de un proxy/CDN**, `$binary_remote_addr` es la IP del proxy: usa `real_ip_header` con `set_real_ip_from`.
- Complementa con fail2ban sobre los 429, bloqueo por cuenta y CAPTCHA.

## Si te atascas

- Sale 503 en vez de 429: falta `limit_req_status 429`.
- `nginx -t` dice "zone unknown": la zona está en un `server`; debe ir en `http` (`conf.d/`).
