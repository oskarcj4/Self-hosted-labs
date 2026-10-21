#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 60. Observa el servicio 12 segundos: si el OOM killer lo
# sigue matando, NRestarts sube.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
prop(){ systemctl show -p "$1" --value report-gen; }

echo "== Lab 60 · OOM killer — comprobación =="
echo "  (observando report-gen durante 12 s...)"

r0=$(prop NRestarts); pid0=$(prop MainPID)
sleep 12
r1=$(prop NRestarts); pid1=$(prop MainPID)

if [ "$(systemctl is-active report-gen)" = active ] && [ "$r0" = "$r1" ] && [ "$pid0" = "$pid1" ] && [ "$pid1" != 0 ]; then
  ok "report-gen lleva estable todo el intervalo (sin reinicios)."
else
  no "report-gen se ha reiniciado durante la observación (NRestarts $r0 -> $r1): lo siguen matando."
fi

F=/var/lib/report-gen/last-report.json
if [ -f "$F" ] && [ $(( $(date +%s) - $(stat -c %Y "$F") )) -lt 12 ]; then
  ok "Los informes vuelven a generarse ($F reciente)."
else
  no "No hay informes recientes en $F."
fi

mm=$(prop MemoryMax)
if [ "$mm" = infinity ] || [ -z "$mm" ]; then
  no "Quitaste el límite de memoria (MemoryMax=infinity): en un host compartido, un fallo así se lleva por delante a los vecinos."
elif [ "$mm" -le $((256*1024*1024)) ]; then
  ok "report-gen sigue con un límite de memoria razonable ($((mm/1024/1024)) MB)."
else
  no "MemoryMax=$((mm/1024/1024)) MB: el presupuesto de este host es de 256 MB como mucho."
fi

if grep -qiE 'oom' /home/analista/incidente/causa.txt 2>/dev/null; then
  ok "La causa está documentada en ~/incidente/causa.txt."
else
  no "~/incidente/causa.txt no contiene la evidencia (la línea del journal que menciona al OOM killer)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 OOM diagnosticado y servicio estable dentro de su presupuesto."; exit 0; } || exit 1
