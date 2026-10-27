#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/edge
c=$(docker ps -q --filter label=com.docker.compose.project=edge --filter label=com.docker.compose.service=api | head -1)

echo "== Lab 90 · Cerrar vías de escape al host — comprobación =="

[ -n "$c" ] || { no "La api no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }

if [ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" = "false" ]; then ok "No es privileged."
else no "Sigue privileged."; fi

pidm=$(docker inspect -f '{{.HostConfig.PidMode}}' "$c")
if [ "$pidm" = "host" ]; then no "pid: host sigue activo."
else ok "PID namespace propio (${pidm:-default})."; fi

netm=$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$c")
if [ "$netm" = "host" ]; then no "network_mode: host sigue activo."
else ok "Red propia ($netm)."; fi

mounts=$(docker inspect -f '{{range .Mounts}}{{.Source}}->{{.Destination}} {{end}}' "$c")
echo "$mounts" | grep -q 'docker.sock' && no "Sigue montando docker.sock." \
  || ok "Sin docker.sock."
if echo "$mounts" | grep -qE '(^|[[:space:]])/->|:/host'; then
  no "Sigue montando / del host."
else
  ok "Sin bind de / del host."
fi
echo "$mounts" | grep -q '/data' && ok "El volumen de datos sigue montado." \
  || no "Falta el montaje de ./data en /data."

cfg=$(cd "$P" && docker compose config 2>/dev/null || cat "$P/compose.yaml")
echo "$cfg" | grep -qiE 'privileged:[[:space:]]*true' && no "compose.yaml sigue pidiendo privileged." \
  || ok "compose.yaml sin privileged."
echo "$cfg" | grep -qi 'docker.sock' && no "compose.yaml sigue montando docker.sock." \
  || ok "compose.yaml sin socket."
echo "$cfg" | grep -qE 'pid:[[:space:]]*host|network_mode:[[:space:]]*host' \
  && no "compose.yaml sigue con pid/net host." \
  || ok "compose.yaml sin pid/net host."
echo "$cfg" | grep -qE '[[:space:]]/:/host|/:/host' && no "compose.yaml sigue con /:/host." \
  || ok "compose.yaml sin / del host."

if curl -sf --max-time 3 http://127.0.0.1:8080/ | grep -q 'edge-ok'; then
  ok "La api sirve edge-ok."
else
  no "curl :8080 no devuelve edge-ok (¿publicaste 8080 al quitar network_mode: host?)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Vías de escape cerradas. ¡Lab 90 resuelto!"; exit 0; } || exit 1
