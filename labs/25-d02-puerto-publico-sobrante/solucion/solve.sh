#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
rm -f /etc/nginx/sites-enabled/compat-test
sed -i '/listen 8080;/d' /etc/nginx/sites-available/shop
nginx -t
systemctl reload nginx
sleep 1
