#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 51 (Día 28). Busca el token en TODAS las imágenes locales
# (también las <none>), en su historial, metadatos y capas.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/notify
TOKEN="ntf_live_2c8e5a17f9b4"
c=$(docker ps -q --filter label=com.docker.compose.project=notify --filter label=com.docker.compose.service=notifier | head -1)

echo "== Lab 51 · Día 28 — comprobación =="

if grep -qF "$TOKEN" "$P/app/Dockerfile" || grep -qE '^\s*(ARG|ENV)\s+NOTIFY_TOKEN' "$P/app/Dockerfile"; then
  no "El Dockerfile sigue declarando o conteniendo el token."
else
  ok "El Dockerfile ya no lleva el token (ni ARG/ENV NOTIFY_TOKEN)."
fi

imgs=$( { docker images -aq; docker ps -aq | xargs -r docker inspect -f '{{.Image}}'; } | sed 's/^sha256://' | cut -c1-12 | sort -u)
dirty=""
for i in $imgs; do
  if docker history --no-trunc "$i" 2>/dev/null | grep -qF "$TOKEN" \
     || docker image inspect "$i" 2>/dev/null | grep -qF "$TOKEN" \
     || docker save "$i" 2>/dev/null | grep -aqF "$TOKEN"; then
    dirty="$dirty $i($(docker image inspect -f '{{join .RepoTags ","}}' "$i" 2>/dev/null | sed 's/^$/<none>/'))"
  fi
done
if [ -z "$dirty" ]; then ok "Ninguna imagen local contiene el token (historial, metadatos ni capas)."
else no "Imágenes que todavía contienen el token:$dirty"; fi

if [ -z "$c" ]; then
  no "notifier no está corriendo."
else
  if docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -qF "$TOKEN"; then
    no "El token está en el entorno del contenedor notifier."
  else
    ok "El token no está en el entorno del contenedor."
  fi
  st=""
  for _ in $(seq 1 8); do
    st=$(docker exec "$c" cat /tmp/status 2>/dev/null)
    echo "$st" | grep -q "ok (file) gateway ok" && break
    sleep 1
  done
  if echo "$st" | grep -q "ok (file) gateway ok"; then ok "notifier se autentica con el token entregado en ejecución (fichero)."
  else no "notifier no se autentica con un token de fichero: ${st:-sin estado}"; fi
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Imagen limpia, secreto en ejecución. ¡Día 28 resuelto!"; exit 0; } || exit 1
