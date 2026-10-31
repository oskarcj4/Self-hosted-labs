#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 112.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 112 · Auditoría con auditd — comprobación =="

H=/home/analista/hallazgos.txt
if [ -s $H ] && grep -qi becario $H && grep -qi usermod $H && grep -qi tee $H; then
  ok "hallazgos.txt identifica la cuenta (auid) y los comandos usados."
else
  no "~/hallazgos.txt debe nombrar la cuenta de login responsable y los dos comandos que modificaron shadow y sudoers."
fi
if grep -q '203.0.113.45' $H 2>/dev/null; then
  ok "hallazgos.txt incluye desde dónde entró (IP de origen)."
else
  no "En hallazgos.txt falta la IP desde la que entró la cuenta (eventos USER_LOGIN)."
fi
if grep -qi operador $H 2>/dev/null && grep -qiE 'operador.*(legítim|legitim|ruido|normal)|(legítim|legitim|ruido|normal).*operador' $H; then
  ok "Distingues el cambio legítimo del operador."
else
  no "En hallazgos.txt aclara qué hizo 'operador' y por qué es legítimo (una línea con 'operador' y 'legítimo')."
fi

if $SUDO grep -q '^backup.*NOPASSWD' /etc/sudoers; then
  no "La regla de sudo para 'backup' sigue en /etc/sudoers."
else
  ok "La regla añadida a /etc/sudoers ya no está."
fi
if $SUDO visudo -c >/dev/null 2>&1; then ok "visudo -c: sudoers válido."; else no "visudo -c falla."; fi
SH=$(getent passwd backup | cut -d: -f7)
PW=$($SUDO getent shadow backup | cut -d: -f2)
if [ "$SH" = /usr/sbin/nologin ] && [[ "$PW" == '*' || "$PW" == '!'* ]]; then
  ok "La cuenta de sistema 'backup' vuelve a estar sin login ni contraseña."
else
  no "'backup' debe volver a shell /usr/sbin/nologin y contraseña bloqueada ('*' o '!')."
fi

RULES=$($SUDO sh -c 'cat /etc/audit/rules.d/*.rules' 2>/dev/null)
if echo "$RULES" | grep -qE -- '-w /etc/shadow .*-k claves' && echo "$RULES" | grep -qE -- '-w /etc/sudoers .*-p wa' && echo "$RULES" | grep -qE -- '-w /etc/sudoers.d/? '; then
  ok "Reglas persistentes en /etc/audit/rules.d/ (shadow, sudoers, sudoers.d)."
else
  no "Faltan reglas persistentes en /etc/audit/rules.d/*.rules para /etc/shadow (-k claves), /etc/sudoers y /etc/sudoers.d/."
fi
if $SUDO augenrules --check 2>&1 | grep -q 'No change'; then
  ok "augenrules generó /etc/audit/audit.rules a partir de rules.d."
else
  no "rules.d y /etc/audit/audit.rules no coinciden: genera y carga con augenrules --load."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Intrusión reconstruida y vigilancia persistente."; exit 0; } || exit 1
