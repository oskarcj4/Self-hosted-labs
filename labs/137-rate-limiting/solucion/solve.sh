#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
sleep 15
awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -3
IP=$(awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
echo "ip_bot=$IP" > $H/limite.txt
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > $H/hey-antes.txt
cat > /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=login:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conexiones:10m;
limit_req_status  429;
limit_conn_status 429;
N
python3 - <<'PY'
p = "/etc/nginx/sites-available/web"
s = open(p).read()
s = s.replace("proxy_pass http://127.0.0.1:9137;",
              "limit_req zone=login burst=10 nodelay;\n        limit_conn conexiones 10;\n        proxy_pass http://127.0.0.1:9137;")
open(p, "w").write(s)
PY
nginx -t && systemctl reload nginx && sleep 2
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > $H/hey-despues.txt
grep -A4 'Status code' $H/hey-despues.txt
chown analista:analista $H/limite.txt $H/hey-*.txt
sleep 2; tail -3 /var/log/nginx/access.log
