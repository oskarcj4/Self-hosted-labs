#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
SOCK=/run/haproxy/admin.sock
curl -si http://127.0.0.1/api/checkout | grep -iE '^HTTP|X-App-Version'
printf 'version_mala=1.5.0\nversion_buena=1.4.0\n' > $H/incidente.txt
sed -i -E 's|^(\s*stats socket \S+ .*)level user|\1level admin|' /etc/haproxy/haproxy.cfg
sed -i -E 's|^(\s*)option httpchk GET /$|\1option httpchk GET /health\n\1http-check expect status 200|' /etc/haproxy/haproxy.cfg
haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl reload haproxy
sleep 2
cat > $H/rollback.sh <<'R'
#!/usr/bin/env bash
# Rollback blue/green por la runtime API de HAProxy: sin reload ni restart.
set -euo pipefail
SOCK=/run/haproxy/admin.sock
api(){ echo "$1" | sudo socat stdio "$SOCK"; }
t0=$(date +%s)
api "set server shop/blue state ready"
api "set server shop/green state maint"
for _ in $(seq 1 30); do
  v=$(curl -s -o /dev/null -D - --max-time 2 http://127.0.0.1/api/checkout | tr -d '\r' | awk -F': ' 'tolower($1)=="x-app-version"{print $2}')
  [ "$v" = 1.4.0 ] && { echo "Rollback OK a $v en $(( $(date +%s) - t0 ))s"; exit 0; }
  sleep 1
done
echo "Rollback NO confirmado" >&2; exit 1
R
chmod +x $H/rollback.sh
chown analista:analista $H/rollback.sh $H/incidente.txt
bash $H/rollback.sh
