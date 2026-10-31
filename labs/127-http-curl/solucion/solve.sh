#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
U=http://tienda.lab
c(){ curl -s -o /dev/null -w '%{http_code}' "$U$1"; }
curl -sI $U/catalogo
L=$(curl -sI $U/catalogo | awk -F': ' 'tolower($1)=="location"{print $2}' | tr -d '\r')
{
  echo "catalogo=$(c /catalogo)"; echo "admin=$(c /admin)"; echo "interno=$(c /interno)"
  echo "no_existe=$(c /no-existe)"; echo "pedidos=$(c /api/pedidos)"; echo "redireccion=$L"
} > /home/analista/codigos.txt
curl -sv $U/api/pedidos -o /dev/null || true
tail -2 /var/log/nginx/error.log
ss -ltnp | grep python
sed -i 's/127.0.0.1:8001/127.0.0.1:8081/' /etc/nginx/sites-available/tienda
nginx -t && systemctl reload nginx && sleep 2
T=$(curl -s -o /dev/null -w '%{time_starttransfer}' $U/api/pedidos)
echo "ttfb_pedidos=$T" >> /home/analista/codigos.txt
chown analista:analista /home/analista/codigos.txt
