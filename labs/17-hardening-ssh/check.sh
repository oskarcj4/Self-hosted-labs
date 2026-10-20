#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 17.
C=/etc/ssh/sshd_config
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

# Devuelve el valor efectivo (última línea activa) de una directiva.
val(){ grep -iE "^[[:space:]]*$1[[:space:]]+" "$C" 2>/dev/null | awk '{print tolower($2)}' | tail -1; }

echo "== Lab 17 — comprobación =="

[ "$(val PermitRootLogin)" = "no" ] \
  && ok "PermitRootLogin está en 'no'." \
  || no "PermitRootLogin debe estar en 'no' (línea activa)."

[ "$(val PasswordAuthentication)" = "no" ] \
  && ok "PasswordAuthentication está en 'no'." \
  || no "PasswordAuthentication debe estar en 'no' (línea activa)."

if sshd -t 2>/dev/null; then
  ok "La configuración es válida (sshd -t)."
else
  no "sshd -t falla: hay un error de sintaxis en la configuración."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 SSH endurecido. ¡Lab 17 resuelto!"; exit 0; } || exit 1
