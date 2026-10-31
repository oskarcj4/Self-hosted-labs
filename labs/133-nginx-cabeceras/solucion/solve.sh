#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
curl -sI http://tienda.lab/ ; curl -s http://tienda.lab/.env | head -2
cat > /etc/nginx/sites-available/tienda <<'N'
server {
    listen 80 default_server;
    server_name tienda.lab;
    root /var/www/tienda;
    index index.html;
    server_tokens off;

    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location ^~ /.well-known/ {
        try_files $uri =404;
    }
    # Cualquier ruta con un segmento que empiece por punto (.env, .git/...).
    location ~ /\. {
        deny all;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    location /cuenta/ {
        proxy_pass http://127.0.0.1:9133/;
        proxy_cookie_flags ~ httponly secure samesite=lax;
    }
}
N
nginx -t && systemctl reload nginx && sleep 1
curl -sI http://tienda.lab/ ; curl -sI http://tienda.lab/cuenta/login | grep -i set-cookie
