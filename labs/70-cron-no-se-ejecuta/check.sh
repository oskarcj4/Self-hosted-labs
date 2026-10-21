#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 70. No lanza nada a mano: espera a que CRON ejecute las
# cinco tareas (hasta 75 s) y mira sus latidos.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
HB=/var/lib/heartbeat
JOBS="limpieza informe metricas backup sync"

echo "== Lab 70 · Cron que no se ejecuta — comprobación =="

systemctl is-active --quiet cron && ok "cron está en marcha." || no "cron no está en marcha."

dots=$(ls /etc/cron.d | grep -E '[^A-Za-z0-9_-]')
[ -z "$dots" ] && ok "Ningún fichero de /etc/cron.d tiene un nombre que cron ignore." \
  || no "cron ignora estos ficheros de /etc/cron.d por su nombre: $dots"

start=$(date +%s)
echo "  (esperando a que cron ejecute las tareas, hasta 75 s; empieza $(date +%T)...)"
while :; do
  pending=""
  for j in $JOBS; do
    [ -f $HB/$j ] && [ "$(stat -c %Y $HB/$j)" -ge "$start" ] || pending="$pending $j"
  done
  [ -z "$pending" ] && break
  [ $(( $(date +%s) - start )) -ge 75 ] && break
  sleep 3
done
for j in $JOBS; do
  if [ -f $HB/$j ] && [ "$(stat -c %Y $HB/$j)" -ge "$start" ]; then
    ok "La tarea '$j' corrió desde cron ($(cat $HB/$j))."
  else
    no "La tarea '$j' no ha corrido desde cron en este minuto."
  fi
done

log=/var/log/backup-db-$(date +%F).log
if [ -f "$log" ] && grep -q 'volcado OK' "$log" && [ "$(stat -c %Y "$log")" -ge "$start" ]; then
  ok "backup-db dejó su log diario: $log"
else
  no "No está $log con la salida de hoy (¿qué hace cron con el '%'?)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Las cinco tareas corren desde cron."; exit 0; } || exit 1
