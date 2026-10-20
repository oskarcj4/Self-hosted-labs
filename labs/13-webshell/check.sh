#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 13.
W=/var/www
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 13 — comprobación =="

HITS="$(grep -rlE 'system\(\$_(GET|POST|REQUEST)|shell_exec\(|passthru\(|eval\(base64_decode' "$W" 2>/dev/null)"
if [ -n "$HITS" ]; then
  no "Todavía hay archivos con patrón de webshell:"
  echo "$HITS" | sed 's/^/        /'
else
  ok "No queda ningún archivo con patrón de webshell."
fi

if [ -f "$W/html/index.html" ]; then
  ok "Los archivos legítimos del sitio siguen presentes (index.html)."
else
  no "Borraste archivos legítimos (falta index.html). Restáuralos."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Webshell eliminada. ¡Lab 13 resuelto!"; exit 0; } || exit 1
