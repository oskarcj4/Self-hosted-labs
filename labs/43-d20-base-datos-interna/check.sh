#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 43 (Día 20).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/inventory
PROJ=inventory
IP=$(hostname -i 2>/dev/null | awk '{print $1}')
cid(){ docker ps -q --filter "label=com.docker.compose.project=$PROJ" --filter "label=com.docker.compose.service=$1" | head -1; }

echo "== Lab 43 · Día 20 — comprobación =="

db=$(cid db)
if [ -z "$db" ]; then
  no "El servicio db no está corriendo."
else
  hp=$(docker inspect -f '{{range $p,$b := .NetworkSettings.Ports}}{{range $b}}{{.HostIp}}:{{.HostPort}} {{end}}{{end}}' "$db")
  if [ -z "$(echo $hp)" ]; then ok "La base de datos no publica ningún puerto en el host."
  else no "db sigue publicando puertos en el host: $hp"; fi
fi

exposed=0
for h in "$IP" 127.0.0.1; do
  if timeout 2 bash -c "exec 3<>/dev/tcp/$h/5432; echo PING >&3; read -r r <&3; [ \"\$r\" = PONG ]" 2>/dev/null; then exposed=1; fi
done
[ "$exposed" -eq 0 ] && ok "Desde el host, :5432 ya no responde." || no "La base de datos responde desde el host en :5432."

r=$(curl -s --max-time 4 "http://$IP:8000/")
if echo "$r" | grep -q "db: PONG"; then ok "La API sigue hablando con la base de datos por la red interna."
else no "La API no llega a la base de datos: ${r:-sin respuesta}"; fi

if (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys
sys.exit(1 if json.load(sys.stdin)["services"]["db"].get("ports") else 0)'; then
  ok "compose.yaml ya no publica puertos para db."
else
  no "compose.yaml sigue publicando puertos para db."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Base de datos sólo interna. ¡Día 20 resuelto!"; exit 0; } || exit 1
