# Rate limiting: frena la fuerza bruta en nginx

> Hardening web · hey · limit_req_zone · limit_conn_zone · 429

## Escenario

El login de `web-137` recibe miles de intentos por minuto y la API va
lenta para todos (`~/ticket/SEC-137.txt`). Sin un límite, un único cliente
puede probar contraseñas sin parar y consumir toda la CPU del backend.

- `limit_req_zone` + `limit_req`: peticiones por segundo por clave (aquí,
  la IP). Con `burst` admites ráfagas cortas; con `nodelay` las sirves al
  momento en vez de encolarlas.
- `limit_conn_zone` + `limit_conn`: conexiones simultáneas por clave.
- Por defecto nginx responde **503** al pasarse; lo correcto para "vas
  demasiado rápido" es **429 Too Many Requests** (`limit_req_status`).

## Objetivos

1. Busca en `/var/log/nginx/access.log` la IP que más pide `/api/login` y
   anótala en `~/limite.txt` como `ip_bot=`.
2. Mide con `hey` **antes** de cambiar nada y guarda la salida en
   `~/hey-antes.txt`.
3. Limita `/api/login` por IP (peticiones/s con ráfaga + conexiones
   simultáneas) respondiendo 429. `/static/` y el resto, sin límite.
4. Mide otra vez y guarda la salida en `~/hey-despues.txt`. Comprueba en
   el access.log que el bot ya recibe 429.

## Comandos que te pueden servir

```bash
sudo awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login
sudo nano /etc/nginx/conf.d/limites.conf          # zonas: contexto http
sudo nano /etc/nginx/sites-available/web          # limit_req / limit_conn: dentro del location
sudo nginx -t && sudo systemctl reload nginx
sudo tail -f /var/log/nginx/access.log | grep ' 429 '
```

> Un límite por IP no basta contra una botnet con miles de IPs: ahí entran
> CAPTCHA, bloqueo por cuenta, fail2ban leyendo los 429 o un WAF/CDN.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
