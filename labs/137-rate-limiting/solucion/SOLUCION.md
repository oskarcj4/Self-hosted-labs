# Solución — Rate limiting contra fuerza bruta

## Qué pasaba

Un bot en `10.137.0.66` envía unas 20 peticiones por segundo a `/api/login`.
nginx las pasaba todas al backend, sin límite por IP.

## Arreglo

```bash
sudo awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -3
echo "ip_bot=10.137.0.66" > ~/limite.txt
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-antes.txt

sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=login:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conexiones:10m;
limit_req_status  429;
limit_conn_status 429;
N
sudo nano /etc/nginx/sites-available/web
#   location /api/login {
#       limit_req zone=login burst=10 nodelay;
#       limit_conn conexiones 10;
#       proxy_pass http://127.0.0.1:9137;
#   }
sudo nginx -t && sudo systemctl reload nginx

hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-despues.txt
sudo tail -n 50 /var/log/nginx/access.log | grep '^10.137.0.66' | grep ' 429 '
bash /opt/lab/check.sh
```

## Más allá del lab

- `limit_req_log_level warn` y fail2ban con un filtro sobre los 429 bloquean al bot en el firewall.
- Contra botnets: límite por cuenta (no por IP), CAPTCHA tras N fallos, WAF/CDN.
