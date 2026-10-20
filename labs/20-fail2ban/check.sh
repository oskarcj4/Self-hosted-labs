#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 20.
IP="198.51.100.23"
J=/etc/fail2ban/jail.local
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 20 — comprobación =="

if [ -f "$J" ] && grep -qiE '^\s*\[sshd\]' "$J" && grep -qiE '^\s*enabled\s*=\s*true' "$J"; then
  ok "jail.local tiene la jail [sshd] habilitada."
else
  no "Falta /etc/fail2ban/jail.local con [sshd] enabled = true."
fi

if fail2ban-client ping 2>/dev/null | grep -qi pong; then
  ok "El servidor fail2ban está en ejecución."
else
  no "El servidor fail2ban no responde (arráncalo con 'fail2ban-client start')."
fi

if fail2ban-client status sshd 2>/dev/null | grep -q "$IP"; then
  ok "La IP atacante está baneada en la jail sshd."
else
  no "La IP $IP no aparece baneada en la jail sshd."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 fail2ban protegiendo SSH. ¡Lab 20 resuelto!"; exit 0; } || exit 1
