#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 33 (Día 10). OJO: fuerza una rotación con logrotate para
# comprobar que los permisos sobreviven a ella.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
AS_ANALISTA=""; [ "$(id -u)" -eq 0 ] && AS_ANALISTA="runuser -u analista --"
L=/var/log/payments
LOG=$L/transactions.log

echo "== Lab 33 · Día 10 — comprobación =="

dmode=$($SUDO stat -c '%a' "$L")
if [ $((8#$dmode & 7)) -eq 0 ]; then ok "La carpeta $L ya no es accesible para otros ($dmode)."
else no "La carpeta $L sigue abierta a otros ($dmode)."; fi

open=$($SUDO find "$L" -mindepth 1 -perm /o=rwx 2>/dev/null)
if [ -z "$open" ]; then ok "Ningún log (actual ni rotado) es accesible para otros."
else no "Logs aún accesibles para otros: $(echo $open)"; fi

if $AS_ANALISTA cat "$LOG" >/dev/null 2>&1 || $AS_ANALISTA cat "$L/transactions.log.1" >/dev/null 2>&1; then
  no "Un usuario normal (analista) todavía puede leer los logs de pagos."
else
  ok "Un usuario normal (analista) ya no puede leer los logs de pagos."
fi

cmode=$(grep -E '^\s*create\s+' /etc/logrotate.d/payments 2>/dev/null | awk '{print $2}' | tail -1)
if [ -n "$cmode" ] && [ $((8#$cmode & 7)) -eq 0 ]; then
  ok "logrotate recreará el log con permisos cerrados (create $cmode)."
else
  no "/etc/logrotate.d/payments recrea el log abierto a otros (create ${cmode:-?})."
fi

# Rotación forzada: debe funcionar y dejar el log nuevo cerrado y escribible por el servicio.
OUT=$(mktemp)
if $SUDO logrotate -f -s /var/lib/logrotate/tclab-check.state /etc/logrotate.d/payments >"$OUT" 2>&1; then
  sleep 5
  nmode=$($SUDO stat -c '%a' "$LOG" 2>/dev/null)
  lines=$($SUDO wc -l "$LOG" 2>/dev/null | awk '{print $1}')
  if [ -n "$nmode" ] && [ $((8#$nmode & 7)) -eq 0 ] && [ "${lines:-0}" -gt 0 ]; then
    ok "Tras rotar, el log nuevo nace cerrado ($nmode) y paymentsd sigue escribiendo en él."
  else
    no "Tras rotar, el log nuevo está abierto (${nmode:-no existe}) o paymentsd no escribe en él."
  fi
else
  no "logrotate falla: $(head -2 "$OUT" | tr '\n' ' ')"
fi

if systemctl is-active --quiet paymentsd && curl -s --max-time 3 http://127.0.0.1:8600/ | grep -q "paymentsd ok" \
   && [ "$(systemctl show paymentsd -p User --value)" = "payments" ]; then
  ok "paymentsd activo, como 'payments', escribiendo sin errores."
else
  no "paymentsd no está sano (curl 127.0.0.1:8600) o ya no corre como 'payments'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Logs de pagos acotados al servicio. ¡Día 10 resuelto!"; exit 0; } || exit 1
