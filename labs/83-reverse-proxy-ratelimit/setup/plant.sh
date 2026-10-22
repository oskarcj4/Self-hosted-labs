#!/usr/bin/env bash
# Planta el escenario del Lab 83: nginx como reverse proxy delante de Apache,
# pero SIN rate limiting. El backend (Apache en 127.0.0.1:8080) queda expuesto a
# cualquier ráfaga que llegue por el proxy. El reto es poner un limitador.
set -e

# --- Backend: Apache en 127.0.0.1:8080 ---
echo "<h1>backend web-83 OK</h1>" > /var/www/html/index.html
cat > /etc/apache2/ports.conf <<'EOF'
Listen 127.0.0.1:8080
EOF
cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost 127.0.0.1:8080>
    DocumentRoot /var/www/html
</VirtualHost>
EOF

# --- Reverse proxy: nginx en :80 -> backend, SIN limit_req ---
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
apachectl start >/dev/null 2>&1 || service apache2 start >/dev/null 2>&1 || true
service nginx start >/dev/null 2>&1 || nginx >/dev/null 2>&1 || true

echo "Lab 83 plantado. Entra como analista y lee /RETO.md"
