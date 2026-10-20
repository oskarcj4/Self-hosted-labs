#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 50 (Día 27).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/files
TOKEN="upl_live_7d3e91c4a0f2"
c=$(docker ps -q --filter label=com.docker.compose.project=files --filter label=com.docker.compose.service=uploader | head -1)

echo "== Lab 50 · Día 27 — comprobación =="

[ -n "$c" ] || { no "uploader no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }

if docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -qF "$TOKEN"; then
  no "El token sigue en el entorno del contenedor (docker inspect lo muestra)."
else
  ok "El token ya no está en el entorno del contenedor."
fi

if grep -rqF "$TOKEN" "$P/compose.yaml" "$P"/compose.*.yaml "$P"/docker-compose*.y*ml "$P/.env" 2>/dev/null; then
  no "El token sigue escrito en compose.yaml / .env."
else
  ok "Ni compose.yaml ni .env contienen el token."
fi

f=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | sed -n 's/^UPLOADER_API_TOKEN_FILE=//p')
if [ -z "$f" ]; then
  no "uploader no tiene UPLOADER_API_TOKEN_FILE apuntando al fichero del secreto."
else
  src=$(docker inspect -f "{{range .Mounts}}{{if eq .Destination \"$f\"}}{{.Source}}|{{.RW}}{{end}}{{end}}" "$c")
  if [ -z "$src" ]; then
    no "$f no es un montaje (¿el token está horneado o copiado dentro del contenedor?)."
  else
    hf=${src%|*}; rw=${src#*|}
    mode=$($SUDO stat -c '%a' "$hf" 2>/dev/null)
    if [ "$rw" = "false" ] && [ -n "$mode" ] && [ $((8#$mode & 077)) -eq 0 ]; then
      ok "El token llega como fichero montado en sólo lectura ($f) desde $hf ($mode)."
    else
      no "El fichero del secreto debe montarse en sólo lectura y ser 0600/0400 en el host ($hf: ${mode:-?}, RW=$rw)."
    fi
  fi
fi

st=""
for _ in $(seq 1 8); do
  st=$(docker exec "$c" cat /tmp/status 2>/dev/null)
  echo "$st" | grep -q "ok (file) storage ok" && break
  sleep 1
done
if echo "$st" | grep -q "ok (file) storage ok"; then ok "uploader se autentica leyendo el token del fichero."
else no "uploader no se autentica con el token de fichero: ${st:-sin estado}"; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Token como fichero, no como variable. ¡Día 27 resuelto!"; exit 0; } || exit 1
