#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 14.
IP="203.0.113.66"
F=/home/analista/hallazgos.txt
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 14 — comprobación =="

if grep -qE "sshd:[[:space:]]*${IP}" /etc/hosts.deny 2>/dev/null; then
  ok "La IP de la brecha está bloqueada en /etc/hosts.deny."
else
  no "Falta bloquear la IP de la brecha en /etc/hosts.deny (sshd: $IP)."
fi

if grep -q "$IP" "$F" 2>/dev/null; then
  ok "Documentaste la IP de la brecha en el informe."
else
  no "Falta documentar la IP de la brecha ($IP) en ~/hallazgos.txt."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Triage completo y brecha bloqueada. ¡Lab 14 resuelto!"; exit 0; } || exit 1
