#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 07.
F=/etc/webadmin/credentials
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 07 — comprobación =="

if [ ! -f "$F" ]; then
  echo "  [✗] No existe $F."; exit 1
fi

PW="$(grep -E '^password=' "$F" | head -1 | cut -d= -f2-)"
WEAK="admin password 123456 12345678 root default admin123 changeme qwerty 1234"

if [ -z "$PW" ]; then
  no "La contraseña está vacía."
elif echo " $WEAK " | grep -qiw "$PW"; then
  no "La contraseña sigue siendo de fábrica / común ('$PW')."
elif [ "${#PW}" -lt 12 ]; then
  no "La contraseña tiene ${#PW} caracteres; necesita al menos 12."
else
  ok "La contraseña es fuerte (${#PW} caracteres, no está en la lista común)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Panel endurecido. ¡Lab 07 resuelto!"; exit 0; } || exit 1
