#!/usr/bin/env bash
# Lab 86: green 1.0.0 en producción (nginx), blue 1.2.0 listo pero fuera del upstream.
set -e
install -d -m 0755 /srv/green /srv/blue /var/lib/tclab
install -m 0755 /opt/lab/setup/app.py /srv/green/app.py
install -m 0755 /opt/lab/setup/app.py /srv/blue/app.py
echo 1.0.0 > /srv/green/VERSION
echo 1.2.0 > /srv/blue/VERSION

cat > /etc/systemd/system/shop-green.service <<'EOF'
[Unit]
Description=shop green (producción actual)
After=network.target
[Service]
Environment=SHOP_NAME=green PORT=8081
WorkingDirectory=/srv/green
ExecStart=/usr/bin/python3 /srv/green/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/shop-blue.service <<'EOF'
[Unit]
Description=shop blue (candidato parcheado)
After=network.target
[Service]
Environment=SHOP_NAME=blue PORT=8082
WorkingDirectory=/srv/blue
ExecStart=/usr/bin/python3 /srv/blue/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'EOF'
upstream shop {
    server 127.0.0.1:8081;   # green — producción
    # server 127.0.0.1:8082; # blue — candidato, aún no recibe tráfico
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
systemctl enable --now shop-green shop-blue nginx
sleep 1
systemctl show -p MainPID --value nginx > /var/lib/tclab/nginx.pid

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-8602.txt <<'EOF'
INC-8602 · shop-cutover · pasar a blue
- Green (:8081) es 1.0.0 y sigue recibiendo TODO el tráfico.
- Blue (:8082) ya corre 1.2.0 y pasa health. Nadie lo apunta.
- Cutover: el upstream de nginx debe quedar SÓLO en blue. Recarga, no restart.
- Green se queda ENCENDIDO: si blue falla, el rollback es volver a apuntar.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 86 plantado."
