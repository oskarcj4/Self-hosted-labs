#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 46 (Día 23). Añade una línea ERROR al log y espera a verla
# reflejada en el resumen.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/logs
c=$(docker ps -q --filter label=com.docker.compose.project=logs --filter label=com.docker.compose.service=collector | head -1)

echo "== Lab 46 · Día 23 — comprobación =="

if [ -z "$c" ] || [ "$(docker inspect -f '{{.State.Restarting}}' "$c")" = "true" ]; then
  no "El colector no está corriendo de forma estable (docker compose ps -a / logs)."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

if [ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" = "false" ]; then ok "El colector ya no es privileged."
else no "El colector sigue con privileged: true."; fi

caps=$(docker inspect -f '{{join .HostConfig.CapAdd " "}}' "$c")
if echo " $caps " | grep -qiE ' (CAP_)?(ALL|SYS_ADMIN|NET_ADMIN|SYS_MODULE|SYS_PTRACE) '; then
  no "Se han añadido capacidades peligrosas en su lugar: $caps"
else
  ok "Sin capacidades extra peligrosas (${caps:-ninguna añadida})."
fi

devs=$(docker inspect -f '{{len .HostConfig.Devices}}' "$c")
if [ "${devs:-0}" -eq 0 ]; then ok "Sin dispositivos del host mapeados."
else no "El colector tiene dispositivos del host mapeados."; fi

before=$($SUDO cat "$P/out/summary.txt" 2>/dev/null | sed -n 's/.*ERROR=\([0-9]*\).*/\1/p')
echo "$(date +%Y-%m-%dT%H:%M:%S) app ERROR prueba-validador" | $SUDO tee -a "$P/logs/app.log" >/dev/null
after="$before"
for _ in $(seq 1 10); do
  sleep 1
  after=$($SUDO cat "$P/out/summary.txt" 2>/dev/null | sed -n 's/.*ERROR=\([0-9]*\).*/\1/p')
  [ -n "$after" ] && [ -n "$before" ] && [ "$after" -gt "$before" ] && break
done
if [ -n "$after" ] && [ -n "$before" ] && [ "$after" -gt "$before" ]; then
  ok "El colector sigue resumiendo el log (ERROR: $before -> $after)."
else
  no "El resumen no refleja la nueva línea ERROR (antes: ${before:-?}, ahora: ${after:-?})."
fi

if (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys
s=json.load(sys.stdin)["services"]["collector"]
sys.exit(1 if s.get("privileged") else 0)'; then
  ok "compose.yaml ya no pide privileged."
else
  no "compose.yaml sigue declarando privileged: true."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Colector sin privilegios. ¡Día 23 resuelto!"; exit 0; } || exit 1
