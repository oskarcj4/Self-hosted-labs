#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 85 · Parche rolling sin downtime — comprobación =="

for u in nginx shop-a shop-b; do
  $SUDO systemctl is-active --quiet "$u" && ok "$u activo." || no "$u no está activo."
done

va=$(curl -s --max-time 3 http://127.0.0.1:8081/version || true)
vb=$(curl -s --max-time 3 http://127.0.0.1:8082/version || true)
echo "$va" | grep -q '1.2.0' && ok "app-a en 1.2.0 ($va)." || no "app-a no está en 1.2.0: ${va:-sin respuesta}"
echo "$vb" | grep -q '1.2.0' && ok "app-b en 1.2.0 ($vb)." || no "app-b no está en 1.2.0: ${vb:-sin respuesta}"

old=0; bad=0; seen=""
for _ in $(seq 1 20); do
  code=$(curl -s -o /tmp/.v85 -w '%{http_code}' --max-time 3 http://127.0.0.1/version || echo 000)
  body=$(cat /tmp/.v85 2>/dev/null)
  [ "$code" = 200 ] || bad=$((bad+1))
  echo "$body" | grep -q '1.0.0' && old=$((old+1))
  seen="$seen $body"
done
[ "$bad" -eq 0 ] && ok "20/20 peticiones al balanceador con 200." || no "$bad de 20 peticiones al LB no dieron 200."
[ "$old" -eq 0 ] && echo "$seen" | grep -q '1.2.0' && ok "El LB sólo sirve 1.2.0." \
  || no "El LB todavía reparte 1.0.0 o no sirve 1.2.0."

vc=$(curl -s -o /tmp/.vuln85 -w '%{http_code}' --max-time 3 http://127.0.0.1/vuln || echo 000)
if [ "$vc" != 200 ]; then ok "/vuln ya no es 200 (código $vc)."
else no "/vuln sigue abierto: $(head -c 80 /tmp/.vuln85)"; fi

now=$($SUDO systemctl show -p MainPID --value nginx)
oldpid=$($SUDO cat /var/lib/tclab/nginx.pid 2>/dev/null || true)
if [ -n "$now" ] && [ "$now" != 0 ] && [ "$now" = "$oldpid" ]; then
  ok "PID maestro de nginx intacto ($now): no hubo restart."
else
  no "nginx se reinició (PID plantado=$oldpid, ahora=$now). Usa reload, no restart."
fi
rm -f /tmp/.v85 /tmp/.vuln85

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Parche rolling sin cortar nginx. ¡Lab 85 resuelto!"; exit 0; } || exit 1
