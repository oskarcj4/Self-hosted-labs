#!/usr/bin/env bash
# Lab 54: tras un reinicio programado, la tienda no vuelve. nginx no arranca
# (config rota + copia de seguridad dentro de sites-enabled) y la API nunca se
# habilitó para el arranque.
set -e
install -m 0755 /opt/lab/setup/svc.py /usr/local/lib/svc.py
id shop >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin shop

cat > /etc/systemd/system/shop-api.service <<'UNIT'
[Unit]
Description=Shop API (backend de la tienda)
After=network.target

[Service]
User=shop
ExecStart=/usr/bin/python3 /usr/local/lib/svc.py shop-api 127.0.0.1 8081
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

mkdir -p /var/www/shop
cat > /var/www/shop/index.html <<'HTML'
<!doctype html><title>Tienda</title><h1>Tienda online</h1><p>Catálogo cargando...</p>
HTML

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'NGX'
server {
    listen 80 default_server;
    server_name shop.local;
    root /var/www/shop;

    location / {
        try_files $uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8081
        proxy_set_header Host $host;
    }
}
NGX
ln -sf /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
# Alguien "hizo backup" antes de tocar la config... dentro de sites-enabled.
sed 's|proxy_pass http://127.0.0.1:8081$|proxy_pass http://127.0.0.1:8081;|' \
  /etc/nginx/sites-available/shop > /etc/nginx/sites-enabled/shop.bak

systemctl daemon-reload
systemctl disable --now nginx shop-api >/dev/null 2>&1 || true

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-2291.txt <<'TXT'
INC-2291 · Prioridad 1 · web-01
03:05  Reinicio programado por parches de kernel.
03:07  Monitor externo: http://web-01/ no responde.
03:20  Guardia de noche: "ayer por la tarde alguien tocó la config de nginx
       para añadir la API, pero no llegó a recargar".
       La API (shop-api) se instaló la semana pasada "a mano".
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 54 plantado."
