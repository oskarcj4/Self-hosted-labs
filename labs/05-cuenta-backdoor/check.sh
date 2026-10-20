#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 05.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 05 — comprobación =="

uid0="$(awk -F: '$3==0 {print $1}' /etc/passwd | sort | tr '\n' ' ')"
if [ "$(echo $uid0)" = "root" ]; then
  ok "La única cuenta con UID 0 es root."
else
  no "Aún hay cuentas con UID 0 además de root: $uid0"
fi

if grep -q '^root:' /etc/passwd; then
  ok "La cuenta root sigue intacta."
else
  no "Borraste la cuenta root. Restáurala."
fi

if [ -f /etc/sudoers.d/backup ]; then
  no "Sigue existiendo la regla de sudo backdoor (/etc/sudoers.d/backup)."
else
  ok "La regla de sudo backdoor fue eliminada."
fi

if [ -f /etc/sudoers.d/analista ]; then
  ok "La regla legítima de analista sigue presente."
else
  no "Borraste la regla legítima de analista. Restáurala."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Backdoors de cuenta erradicados. ¡Lab 05 resuelto!"; exit 0; } || exit 1
