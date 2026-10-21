#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /tmp
openssl req -new -newkey rsa:2048 -nodes -keyout shop-2026.key -out shop-2026.csr \
  -subj "/O=TerminalCero/CN=shop.local" \
  -addext "subjectAltName=DNS:shop.local,DNS:www.shop.local" 2>/dev/null
openssl ca -batch -config /etc/pki/ca/openssl.cnf -days 90 -in shop-2026.csr -out shop-2026.crt 2>/dev/null
cp /etc/nginx/tls/shop.crt /etc/nginx/tls/shop.crt.caducado
install -m 0600 -o root -g root shop-2026.key /etc/nginx/tls/shop.key
install -m 0644 -o root -g root shop-2026.crt /etc/nginx/tls/shop.crt
rm -f shop-2026.key shop-2026.csr shop-2026.crt
nginx -t
systemctl reload nginx
sleep 1
