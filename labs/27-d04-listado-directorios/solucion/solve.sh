#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
sed -i 's/autoindex on;/autoindex off;/' /etc/nginx/conf.d/00-legacy.conf /etc/nginx/sites-available/files
nginx -t
systemctl reload nginx
sleep 1
