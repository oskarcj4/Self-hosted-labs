#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 23.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 23 — comprobación =="

DEVOPS_RULES="$(grep -rhs '^[[:space:]]*devops[[:space:]]' /etc/sudoers /etc/sudoers.d 2>/dev/null)"
if [ -z "$DEVOPS_RULES" ]; then
  ok "La cuenta devops ya no tiene permisos de sudo."
else
  no "devops todavía tiene reglas de sudo: $DEVOPS_RULES"
fi

if id deploy >/dev/null 2>&1; then
  ok "El usuario deploy existe."
else
  no "Falta crear el usuario deploy."
fi

DEP="$(grep -rhs '^[[:space:]]*deploy[[:space:]]' /etc/sudoers /etc/sudoers.d 2>/dev/null)"
if echo "$DEP" | grep -q 'apt-get update' && ! echo "$DEP" | grep -qiE 'NOPASSWD:[[:space:]]*ALL|=\(ALL\)[[:space:]]+ALL|\)[[:space:]]*ALL$'; then
  ok "deploy tiene sudo limitado a un único comando."
else
  no "deploy debe poder ejecutar SÓLO '/usr/bin/apt-get update' vía sudo (no ALL)."
fi

if visudo -c >/dev/null 2>&1; then
  ok "La configuración de sudo es válida (visudo -c)."
else
  no "visudo -c falla: hay un error de sintaxis en sudoers."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Mínimo privilegio aplicado. ¡Lab 23 resuelto!"; exit 0; } || exit 1
