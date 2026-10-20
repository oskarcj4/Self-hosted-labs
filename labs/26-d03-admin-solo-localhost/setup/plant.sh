#!/usr/bin/env bash
# Lab 26 (Día 03): panel de administración escuchando en todas las interfaces
# y, además, publicado a través de nginx en /admin/.
set -e
id opsadmin >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin opsadmin
install -d -m 0755 /opt/ops-admin /etc/ops-admin
install -m 0755 /opt/lab/setup/admin.py /opt/ops-admin/admin.py
cat > /etc/ops-admin/admin.conf <<'EOF'
# ops-admin — configuración
# Abierto a todas las interfaces "temporalmente" para depurar desde la VPN.
BIND_ADDR=0.0.0.0
PORT=9090
EOF
cat > /etc/systemd/system/ops-admin.service <<'EOF'
[Unit]
Description=ops-admin (panel de administración interno)
After=network.target

[Service]
User=opsadmin
ExecStart=/usr/bin/python3 /opt/ops-admin/admin.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/www/ops
echo '<h1>Portal de operaciones</h1><p>Estado: todo verde.</p>' > /var/www/ops/index.html
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/ops <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/ops;
    index index.html;

    # Acceso cómodo al panel desde fuera (añadido por soporte)
    location /admin/ {
        proxy_pass http://127.0.0.1:9090/;
    }
}
EOF
ln -sf /etc/nginx/sites-available/ops /etc/nginx/sites-enabled/ops
nginx -t
systemctl daemon-reload
systemctl enable --now ops-admin nginx
echo "Lab 26 plantado."
