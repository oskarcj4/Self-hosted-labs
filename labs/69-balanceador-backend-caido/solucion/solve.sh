#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cat > /etc/nginx/sites-available/tienda <<'EOF'
upstream tienda {
    zone tienda 64k;
    server 10.76.69.21:8080 max_fails=1 fail_timeout=15s;   # app1
    server 10.76.69.22:8080 max_fails=1 fail_timeout=15s;   # app2
    server 10.76.69.23:8080 max_fails=1 fail_timeout=15s;   # app3
}

server {
    listen 80 default_server;
    server_name tienda.local;

    location / {
        proxy_pass http://tienda;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 1s;
        proxy_read_timeout 2s;
        proxy_next_upstream error timeout http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 3s;
    }
}
EOF
nginx -t
systemctl reload nginx
