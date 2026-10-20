#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 52 (Día 29). Revisa la imagen que usa el contenedor en
# ejecución, no sólo el Dockerfile.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/reports
c=$(docker ps -q --filter label=com.docker.compose.project=reports --filter label=com.docker.compose.service=worker | head -1)

echo "== Lab 52 · Día 29 — comprobación =="

from=$(grep -iE '^\s*FROM\s' "$P/app/Dockerfile" | tail -1 | awk '{print $2}')
if echo "$from" | grep -qE '@sha256:[0-9a-f]{64}$|^python:3\.[0-9]+(\.[0-9]+)?-alpine'; then
  ok "La imagen base está fijada ($from)."
else
  no "La imagen base no está fijada a una versión concreta ($from)."
fi

[ -n "$c" ] || { no "El worker no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }
img=$(docker inspect -f '{{.Image}}' "$c")

if docker image inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$img" | grep -qE '^DEBUG='; then
  no "La imagen en uso sigue definiendo DEBUG."
else
  ok "La imagen en uso no define DEBUG."
fi
if docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -qE '^DEBUG=1'; then
  no "El contenedor arranca con DEBUG=1."
fi

if docker image inspect -f '{{json .Config.ExposedPorts}}' "$img" | grep -q '5678'; then
  no "La imagen sigue declarando EXPOSE 5678 (depurador)."
else
  ok "La imagen ya no expone el puerto del depurador."
fi

files=$(docker run --rm --entrypoint sh "$img" -c 'ls -a /app' 2>/dev/null)
bad=$(echo "$files" | grep -xE 'debug|tests|\.env.*|Dockerfile|\.dockerignore' | tr '\n' ' ')
if [ -z "$bad" ] && echo "$files" | grep -qx 'worker.py'; then
  ok "La imagen sólo lleva lo necesario (sin debug/, tests/, .env.debug)."
else
  no "La imagen todavía incluye: ${bad:-(o le falta worker.py)}"
fi

if docker exec "$c" python -c "import socket; socket.create_connection(('127.0.0.1',5678),timeout=2)" 2>/dev/null; then
  no "El depurador remoto sigue escuchando en el contenedor (:5678)."
else
  ok "El depurador remoto no está activo."
fi

r=""
for _ in $(seq 1 12); do
  r=$($SUDO cat "$P/out/report.txt" 2>/dev/null)
  [ "$r" = "pedidos=4 importe=301.25" ] && break
  sleep 1
done
if [ "$r" = "pedidos=4 importe=301.25" ]; then ok "El worker sigue generando el informe correcto ($r)."
else no "El informe no es correcto: ${r:-no existe}"; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Imagen de producción limpia. ¡Día 29 resuelto!"; exit 0; } || exit 1
