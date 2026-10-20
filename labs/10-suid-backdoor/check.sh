#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 10.
R=/usr/bin/.dbus-cache
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 10 — comprobación =="

if [ -e "$R" ] && [ -u "$R" ]; then
  no "El binario SUID backdoor ($R) sigue teniendo el bit SUID."
else
  ok "El backdoor SUID fue neutralizado (borrado o sin bit SUID)."
fi

if [ -u /usr/bin/sudo ]; then
  ok "El SUID legítimo de sudo sigue intacto."
else
  no "Afectaste a /usr/bin/sudo (debe conservar su SUID). Restáuralo."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Backdoor SUID eliminado. ¡Lab 10 resuelto!"; exit 0; } || exit 1
