#!/usr/bin/env bash
# Lab 85: nginx + dos instancias shop 1.0.0. El parche 1.2.0 espera en /opt/shop/releases.
set -e
install -d -m 0755 /opt/shop/releases/1.0.0 /opt/shop/releases/1.2.0 /srv/app-a /srv/app-b /var/lib/tclab
install -m 0755 /opt/lab/setup/app.py /opt/shop/releases/1.0.0/app.py
install -m 0755 /opt/lab/setup/app.py /opt/shop/releases/1.2.0/app.py
echo 1.0.0 > /opt/shop/releases/1.0.0/VERSION
echo 1.2.0 > /opt/shop/releases/1.2.0/VERSION
cp -a /opt/shop/releases/1.0.0/. /srv/app-a/
cp -a /opt/shop/releases/1.0.0/. /srv/app-b/

cat > /etc/systemd/system/shop-a.service <<'EOF'
[Unit]
Description=shop backend A
After=network.target

[Service]
Environment=SHOP_NAME=app-a PORT=8081
WorkingDirectory=/srv/app-a
ExecStart=/usr/bin/python3 /srv/app-a/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/shop-b.service <<'EOF'
[Unit]
Description=shop backend B
After=network.target

[Service]
Environment=SHOP_NAME=app-b PORT=8082
WorkingDirectory=/srv/app-b
ExecStart=/usr/bin/python3 /srv/app-b/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'EOF'
upstream shop {
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}
server {
    listen 80 default_server;
    location / {
        proxy_pass http://shop;
        proxy_set_header Host $host;
    }
}
EOF
ln -sf /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
systemctl daemon-reload
systemctl enable --now shop-a shop-b nginx
sleep 1
systemctl show -p MainPID --value nginx > /var/lib/tclab/nginx.pid

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-8501.txt <<'EOF'
INC-8501 · shop-lb · CVE-2024-SHOP en 1.0.0
- nginx reparte entre app-a (:8081) y app-b (:8082).
- El parche es 1.2.0 en /opt/shop/releases/1.2.0 (cambia VERSION; /vuln pasa a 404).
- Producción no admite corte: el PID maestro de nginx debe seguir siendo el mismo
  (reload sí, restart no). Parchea un backend, comprueba, luego el otro.
- No dejes un backend en 1.0.0 "para no tocar".
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 85 plantado."
