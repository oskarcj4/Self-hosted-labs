#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 01. Sale 0 si todos los objetivos están cumplidos.
ATTACKER_IP="185.220.101.47"
ROGUE_COMMENT="mallory@evil"
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 01 — comprobación =="

# Obj 2: llave rogue eliminada
if grep -q "$ROGUE_COMMENT" /home/analista/.ssh/authorized_keys 2>/dev/null; then
  no "La llave del atacante ($ROGUE_COMMENT) sigue en authorized_keys."
else
  ok "La llave del atacante fue eliminada de authorized_keys."
fi

# Obj 2b: no te pasaste borrando la llave legítima
if grep -q "analista@prod-web-01" /home/analista/.ssh/authorized_keys 2>/dev/null; then
  ok "La llave legítima del analista sigue presente."
else
  no "Borraste también la llave legítima (analista@prod-web-01). Restáurala."
fi

# Obj 3: trampa en .bashrc neutralizada
if grep -qE 'source[[:space:]]+/dev/shm/\.update|\. /dev/shm/\.update' /home/analista/.bashrc 2>/dev/null; then
  no "La trampa que hace 'source /dev/shm/.update' sigue en ~/.bashrc."
else
  ok "La trampa en ~/.bashrc fue neutralizada."
fi

# Obj 3b: payload borrado
if [ -f /dev/shm/.update ]; then
  no "El payload /dev/shm/.update todavía existe."
else
  ok "El payload /dev/shm/.update fue eliminado."
fi

# Obj 4: IP bloqueada
if grep -qE "sshd:[[:space:]]*${ATTACKER_IP}" /etc/hosts.deny 2>/dev/null; then
  ok "La IP del atacante está bloqueada en /etc/hosts.deny."
else
  no "Falta bloquear la IP $ATTACKER_IP en /etc/hosts.deny (sshd: $ATTACKER_IP)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Servidor blindado. ¡Lab 01 resuelto!"; exit 0; } || exit 1
