#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
U=/var/www/media/uploads
chown -R www-data:www-data "$U"
find "$U" -type d -exec chmod 0755 {} +
find "$U" -type f -exec chmod 0644 {} +
