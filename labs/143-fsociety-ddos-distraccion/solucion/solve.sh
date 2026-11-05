#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
DAT=/opt/allsafe/.fsociety/fsociety00.dat
sleep 15

# 1) Límite en nginx
cat > /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=raiz:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conx:10m;
limit_req_status  429;
limit_conn_status 429;
N
python3 - <<'PY'
p = "/etc/nginx/sites-available/allsafe"
s = open(p).read()
s = s.replace("    location / {\n        try_files $uri $uri/ =404;\n    }",
              "    location / {\n        limit_req zone=raiz burst=10 nodelay;\n        limit_conn conx 10;\n        try_files $uri $uri/ =404;\n    }", 1)
open(p, "w").write(s)
PY
nginx -t && systemctl reload nginx && sleep 2

# 2) Hallazgos
cat > $H/hallazgos.txt <<H
ip_ddos=10.143.0.66
ruta_persistencia=/etc/cron.d/fsociety
binario_beacon=/usr/local/bin/fsociety-beacon
fsociety_dat=$DAT
sha256_dat=$(sha256sum $DAT | cut -d' ' -f1)
H

# 3) Timeline
cat > $H/timeline.txt <<T
02:11  inicio del DDoS a / desde 10.143.0.66
02:14  persistencia plantada (cron.d/fsociety + fsociety-beacon) y cae fsociety00.dat
El DDoS fue la distracción.
T
chown analista:analista $H/hallazgos.txt $H/timeline.txt

# 4) Erradica la persistencia, conserva el .dat
rm -f /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon
systemctl restart cron
pkill -f fsociety-beacon 2>/dev/null || true
echo "solve.sh completado."
