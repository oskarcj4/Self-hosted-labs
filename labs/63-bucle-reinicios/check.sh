#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 63. Observa el servicio 8 segundos para descartar que siga
# en bucle.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
prop(){ systemctl show -p "$1" --value payments-worker; }

echo "== Lab 63 · Bucle de reinicios — comprobación =="

U=$(systemctl cat payments-worker 2>/dev/null)
echo "$U" | grep -qE '^EnvironmentFile=-?/etc/payments/payments\.env' \
  && ok "La unit carga /etc/payments/payments.env." \
  || no "La unit no carga /etc/payments/payments.env (EnvironmentFile=)."
echo "$U" | grep -qE 'PAYMENTS_API_URL|tok_live' \
  && no "La URL o el token están escritos dentro de la unit: deben venir del fichero de /etc/payments/." \
  || ok "La unit no lleva secretos ni URLs dentro."

if systemctl is-active --quiet debug-9090 2>/dev/null; then
  no "El servidor de depuración debug-9090 sigue en marcha."
else
  ok "El servidor de depuración olvidado está parado."
fi

echo "  (observando payments-worker 8 s...)"
r0=$(prop NRestarts); p0=$(prop MainPID)
sleep 8
r1=$(prop NRestarts); p1=$(prop MainPID)
if [ "$(systemctl is-active payments-worker)" = active ] && [ "$r0" = "$r1" ] && [ "$p0" = "$p1" ] && [ "$p1" != 0 ]; then
  ok "payments-worker está activo y estable (sin reinicios)."
else
  no "payments-worker no está estable (estado $(systemctl is-active payments-worker), reinicios $r0 -> $r1)."
fi

owner=$($SUDO ss -Hltnp 'sport = :9090' 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
[ "$owner" = payments-worker ] && ok "El puerto 9090 lo tiene payments-worker." \
  || no "El puerto 9090 lo tiene '${owner:-nadie}'."

curl -fs --max-time 3 http://127.0.0.1:9090/health | grep -q 'payments-worker ok' \
  && ok "/health de payments-worker responde." || no "http://127.0.0.1:9090/health no responde como payments-worker."

[ "$(systemctl is-enabled payments-worker 2>/dev/null)" = enabled ] \
  && ok "payments-worker arranca en el boot." || no "payments-worker no está habilitado."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Bucle de reinicios cortado de raíz."; exit 0; } || exit 1
