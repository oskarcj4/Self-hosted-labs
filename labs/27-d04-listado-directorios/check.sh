#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 27 (Día 04).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IP=$(hostname -I | awk '{print $1}')
B="http://$IP"

echo "== Lab 27 · Día 04 — comprobación =="

listed=""
for dir in /downloads/ /downloads/drivers/ /downloads/internal/ /assets/; do
  body=$(curl -s --max-time 3 "$B$dir")
  echo "$body" | grep -qi "Index of" && listed="$listed $dir"
done
if [ -z "$listed" ]; then
  ok "Ningún directorio muestra su listado (Index of)."
else
  no "Siguen listándose:$listed"
fi

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$B/downloads/")
if [ "$code" = "403" ] || [ "$code" = "404" ]; then
  ok "/downloads/ responde $code en lugar de un listado."
else
  no "/downloads/ responde $code (se espera 403 o 404)."
fi

okfiles=1
for f in /downloads/manual-usuario.pdf /downloads/release-notes.txt /downloads/drivers/driver-v2.bin /assets/site.css /; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$B$f")
  [ "$c" = "200" ] || { okfiles=0; no "$f debería seguir descargándose (responde $c)."; }
done
[ "$okfiles" -eq 1 ] && ok "Los archivos enlazados se siguen descargando con normalidad (200)."

if $SUDO nginx -T 2>/dev/null | grep -vE '^\s*#' | grep -qE 'autoindex\s+on'; then
  no "La configuración efectiva (nginx -T) aún contiene 'autoindex on'."
else
  ok "No queda ningún 'autoindex on' en la configuración efectiva."
fi

if $SUDO nginx -t >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
  ok "nginx tiene configuración válida y está activo."
else
  no "nginx -t falla o nginx no está activo."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Listado de directorios desactivado. ¡Día 04 resuelto!"; exit 0; } || exit 1
