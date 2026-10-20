#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 15.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 15 — comprobación =="

if [ -e /usr/local/bin/ls ]; then
  no "El impostor /usr/local/bin/ls todavía existe."
else
  ok "El impostor /usr/local/bin/ls fue eliminado."
fi

hash -r 2>/dev/null || true
RES="$(command -v ls)"
if [ "$RES" = "/bin/ls" ] || [ "$RES" = "/usr/bin/ls" ]; then
  ok "El comando 'ls' vuelve a resolver al binario legítimo ($RES)."
else
  no "'ls' sigue resolviendo a '$RES' (debería ser /bin/ls o /usr/bin/ls)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 PATH restaurado. ¡Lab 15 resuelto!"; exit 0; } || exit 1
