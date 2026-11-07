#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
L=/var/log/pedidos
I=/home/analista/incidente
PM=$I/postmortem.md

echo "== Lab 178 · Incidente completo — comprobación =="

N=0; for _ in 1 2 3 4 5; do [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8080/pedidos)" = 200 ] && N=$((N+1)); done
USO=$(df --output=pcent $L | tail -1 | tr -dc 0-9)
if [ "$N" = 5 ] && [ "$USO" -lt 60 ]; then
  ok "Servicio restaurado: 5/5 peticiones 200 y el volumen de logs al $USO %."
else
  no "Servicio: $N/5 peticiones 200, volumen de logs al $USO %."
fi

ENVV=$(systemctl show pedidos -p Environment --value)
S0=$(stat -c %s $L/app.log 2>/dev/null || echo 0)
for _ in $(seq 1 20); do curl -s -o /dev/null --max-time 3 http://127.0.0.1:8080/pedidos; done
S1=$(stat -c %s $L/app.log 2>/dev/null || echo 0)
if ! echo "$ENVV" | grep -q 'LOG_LEVEL=DEBUG' && [ $((S1 - S0)) -lt 20000 ]; then
  ok "La app ya no registra en DEBUG ($(( (S1 - S0) / 20 )) bytes por petición)."
else
  no "La app sigue en DEBUG o escribe demasiado ($(( (S1 - S0) / 20 )) bytes por petición)."
fi

LR=/etc/logrotate.d/pedidos
if [ -f "$LR" ] && grep -q "$L" "$LR" && grep -qE '^\s*rotate\s+[0-9]+' "$LR" && grep -qE '^\s*(size|maxsize)\s+' "$LR" \
   && grep -qE '^\s*compress' "$LR" && grep -qE '^\s*(copytruncate|postrotate)' "$LR" && logrotate -d "$LR" >/dev/null 2>&1; then
  logrotate -f "$LR" >/dev/null 2>&1
  sleep 1
  M="rotacion-$RANDOM$RANDOM"
  curl -s -o /dev/null --max-time 3 "http://127.0.0.1:8080/pedidos?$M"
  sleep 1
  if grep -q "$M" $L/app.log 2>/dev/null && { ls $L/*.gz >/dev/null 2>&1 || grep -qE '^\s*delaycompress' "$LR"; }; then
    ok "logrotate rota por tamaño, comprime, limita copias y la app sigue escribiendo en app.log tras rotar."
  else
    no "Tras forzar la rotación, la app no escribe en el app.log nuevo o no se comprime (¿copytruncate?)."
  fi
else
  no "/etc/logrotate.d/pedidos debe tener rotate N, size/maxsize, compress y copytruncate (o postrotate)."
fi

C=$(cat $I/comunicado.txt 2>/dev/null)
NU=$(echo "$C" | grep -cE '^\s*[-*]?\s*\[?[0-2]?[0-9]:[0-5][0-9]')
if [ "$NU" -ge 2 ] && echo "$C" | grep -qiE 'resuelto|restablecido|solucionado'; then
  ok "Comunicado con $NU actualizaciones con hora, hasta la resolución."
else
  no "~/incidente/comunicado.txt: al menos dos actualizaciones con hora (HH:MM), la última de resolución."
fi

FE=$(cut -c12-16 /opt/lab/.primer_error 2>/dev/null)           # HH:MM del primer error
DEP=$(awk '{print substr($2,1,5)}' /var/log/despliegues.log | tail -1)
if [ -f "$PM" ]; then
  sec(){ sed -n "/^#\+ *\($1\)/I,/^#/{/^#/!p}" "$PM"; }
  MISS=""
  for s in 'Resumen' 'Impacto' 'L\(i\|í\)nea de tiempo' 'Causa ra\(i\|í\)z' 'Qu\(e\|é\) funcion' 'Acciones'; do
    grep -qi "^#\+ *$s" "$PM" || MISS="$MISS [$(printf %s "$s" | tr -d '\\')]"
  done
  TL=$(sec 'L\(i\|í\)nea de tiempo')
  AC=$(sec 'Acciones' | grep -cE '^\s*[-*]')
  if [ -n "$MISS" ]; then
    no "postmortem.md: faltan secciones:$MISS."
  elif ! echo "$TL" | grep -q "$FE" || ! echo "$TL" | grep -q "$DEP"; then
    no "Línea de tiempo: incluye las horas reales del despliegue ($DEP) y del primer error ($FE)."
  elif [ "$AC" -lt 2 ]; then
    no "Acciones: al menos dos, con responsable y fecha."
  elif grep -qi 'marta' "$PM"; then
    no "El postmortem nombra a una persona: debe ser sin culpables (habla del sistema, no de quién)."
  else
    ok "Postmortem completo, con horas reales, acciones y sin culpables."
  fi
else
  no "Falta ~/incidente/postmortem.md."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Incidente cerrado de principio a fin."; exit 0; } || exit 1
