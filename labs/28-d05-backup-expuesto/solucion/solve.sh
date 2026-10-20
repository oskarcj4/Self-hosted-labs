#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
install -d -m 700 /root/evidencia
mv /var/www/shop/backup-2026-10-01.tar.gz /var/www/shop/assets/.cache/site-old.tgz /root/evidencia/
chmod 600 /root/evidencia/*
rmdir /var/www/shop/assets/.cache 2>/dev/null || true
