#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 86 · Cutover blue-green — comprobación =="

$SUDO systemctl is-active --quiet nginx && ok "nginx activo." || no "nginx caído."
$SUDO systemctl is-active --quiet shop-blue && ok "blue activo." || no "blue no está activo."
$SUDO systemctl is-active --quiet shop-green && ok "green sigue activo (rollback)." \
  || no "green está apagado: el rollback instantáneo desapareció."

g=$(curl -s --max-time 3 http://127.0.0.1:8081/version || true)
b=$(curl -s --max-time 3 http://127.0.0.1:8082/version || true)
echo "$g" | grep -q '1.0.0 green' && ok "green intacto en 1.0.0." || no "green ya no responde 1.0.0: ${g:-?}"
echo "$b" | grep -q '1.2.0 blue' && ok "blue en 1.2.0." || no "blue no está en 1.2.0: ${b:-?}"

bad=0; wrong=0
for _ in $(seq 1 12); do
  code=$(curl -s -o /tmp/.v86 -w '%{http_code}' --max-time 3 http://127.0.0.1/version || echo 000)
  body=$(cat /tmp/.v86 2>/dev/null)
  [ "$code" = 200 ] || bad=$((bad+1))
  echo "$body" | grep -q '1.2.0 blue' || wrong=$((wrong+1))
done
[ "$bad" -eq 0 ] && [ "$wrong" -eq 0 ] && ok "El LB sólo sirve 1.2.0 blue." \
  || no "El LB aún mezcla versiones o falla (http≠200: $bad, no-blue: $wrong)."

vc=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1/vuln || echo 000)
[ "$vc" != 200 ] && ok "/vuln cerrado en el LB ($vc)." || no "/vuln sigue abierto en el LB."

conf=$($SUDO nginx -T 2>/dev/null)
up=$(echo "$conf" | awk '/upstream shop/{f=1} f; f&&/}/{exit}')
if echo "$up" | grep -qE '127\.0\.0\.1:8082' && ! echo "$up" | grep -qE '^[[:space:]]*server[[:space:]]+127\.0\.0\.1:8081'; then
  ok "Upstream activo: sólo blue (:8082)."
else
  no "El upstream todavía incluye green (:8081) o no apunta a blue."
fi

now=$($SUDO systemctl show -p MainPID --value nginx)
oldpid=$($SUDO cat /var/lib/tclab/nginx.pid 2>/dev/null || true)
if [ -n "$now" ] && [ "$now" != 0 ] && [ "$now" = "$oldpid" ]; then
  ok "PID maestro de nginx intacto ($now)."
else
  no "nginx se reinició (plantado=$oldpid, ahora=$now). Recarga, no restart."
fi
rm -f /tmp/.v86

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Cutover a blue sin tumbar green ni nginx. ¡Lab 86 resuelto!"; exit 0; } || exit 1
