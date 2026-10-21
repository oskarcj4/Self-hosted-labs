#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
sed -i 's|proxy_pass http://127.0.0.1:8081$|proxy_pass http://127.0.0.1:8081;|' /etc/nginx/sites-available/shop
mkdir -p /root/nginx-backups
mv /etc/nginx/sites-enabled/shop.bak /root/nginx-backups/
nginx -t
systemctl enable --now shop-api nginx
