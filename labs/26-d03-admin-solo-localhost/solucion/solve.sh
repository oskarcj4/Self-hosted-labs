#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
sed -i 's/^BIND_ADDR=.*/BIND_ADDR=127.0.0.1/' /etc/ops-admin/admin.conf
systemctl restart ops-admin
sed -i '/# Acceso cómodo al panel/,/^    }/d' /etc/nginx/sites-available/ops
nginx -t
systemctl reload nginx
sleep 1
