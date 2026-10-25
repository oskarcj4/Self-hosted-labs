#!/usr/bin/env bash
set -e
cat > /etc/nginx/sites-available/shop <<'EOF'
upstream shop {
    server 127.0.0.1:8082;   # blue
}
server {
    listen 80 default_server;
    location / {
        proxy_pass http://shop;
        proxy_set_header Host $host;
    }
}
EOF
nginx -t
systemctl reload nginx
