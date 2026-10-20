#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 49 (Día 26). Las comprobaciones de alcance se hacen desde
# dentro de los contenedores.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
cid(){ docker ps -q --filter label=com.docker.compose.project=store --filter "label=com.docker.compose.service=$1" | head -1; }
nets(){ docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$1" | tr ' ' '\n' | grep . | sort; }
reach(){ docker exec "$1" python -c "import socket,sys; socket.create_connection(('$2',$3),timeout=2)" 2>/dev/null; }

echo "== Lab 49 · Día 26 — comprobación =="

W=$(cid web); A=$(cid api); D=$(cid db)
if [ -z "$W" ] || [ -z "$A" ] || [ -z "$D" ]; then
  no "Faltan servicios corriendo (web, api, db)."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

wd=$(comm -12 <(nets "$W") <(nets "$D"))
if [ -z "$wd" ]; then ok "web y db no comparten ninguna red."
else no "web y db siguen en la misma red: $(echo $wd)"; fi

if [ -n "$(comm -12 <(nets "$W") <(nets "$A"))" ] && [ -n "$(comm -12 <(nets "$A") <(nets "$D"))" ]; then
  ok "api comparte red con web y con db (es el único puente)."
else
  no "api debe compartir una red con web y otra con db."
fi

if reach "$W" db 5432; then no "Desde web todavía se llega a db:5432."
else ok "Desde web ya no se llega a db:5432."; fi

r=$(curl -s --max-time 5 http://127.0.0.1:8080/)
if echo "$r" | grep -q "web ok -> api ok -> db PONG"; then ok "La cadena web -> api -> db sigue funcionando."
else no "La cadena no funciona: ${r:-sin respuesta}"; fi

dn=$(nets "$D" | head -1)
if [ -n "$dn" ] && [ "$(docker network inspect -f '{{.Internal}}' "$dn" 2>/dev/null)" = "true" ]; then
  ok "La red de db es interna (sin salida a internet). Extra conseguido."
else
  echo "  [i] Extra opcional: marca la red de db como 'internal: true'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Red segmentada por capas. ¡Día 26 resuelto!"; exit 0; } || exit 1
