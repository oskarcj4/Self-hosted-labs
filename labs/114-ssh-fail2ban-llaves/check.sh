#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 114.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 114 · SSH: fail2ban y sólo llave — comprobación =="
A=/home/analista/respuestas.txt
N=$($SUDO grep -c "Failed password" /var/log/auth.log.1)
TOP=$($SUDO grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
if grep -qE "^intentos=$N\$" $A 2>/dev/null; then ok "Recuento de intentos correcto."; else no "~/respuestas.txt: falta 'intentos=<N>' correcto (auth.log.1)."; fi
if grep -qE "^top=$TOP\$" $A 2>/dev/null; then ok "IP con más intentos correcta."; else no "~/respuestas.txt: falta 'top=<IP>' correcta."; fi

if systemctl is-active -q fail2ban && $SUDO fail2ban-client status sshd >/dev/null 2>&1; then
  ok "fail2ban activo con la jail sshd."
else
  no "fail2ban no está activo o no tiene la jail sshd."
fi
systemctl is-enabled -q fail2ban 2>/dev/null && ok "fail2ban arranca con el sistema." || no "fail2ban no está habilitado (enable)."
MR=$($SUDO fail2ban-client get sshd maxretry 2>/dev/null)
[ "$MR" = 3 ] && ok "maxretry = 3." || no "maxretry de la jail sshd no es 3 (es '${MR:-?}')."
ATK=$(getent hosts atacante | awk '{print $1}')
if [ -n "$ATK" ] && $SUDO fail2ban-client status sshd 2>/dev/null | grep -q "$ATK"; then
  ok "El bot en vivo ($ATK) está baneado."
else
  no "El bot que ataca ahora mismo no aparece baneado en la jail sshd."
fi

T=$($SUDO sshd -T 2>/dev/null)
echo "$T" | grep -qx 'passwordauthentication no' && ok "PasswordAuthentication no." || no "sshd sigue aceptando contraseñas."
echo "$T" | grep -qx 'kbdinteractiveauthentication no' && ok "KbdInteractiveAuthentication no." || no "KbdInteractiveAuthentication sigue activo (otra vía de contraseña)."
if ssh -n -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 analista@127.0.0.1 true 2>/dev/null; then
  ok "analista entra por SSH con su llave."
else
  no "analista no puede entrar con llave (ssh analista@127.0.0.1): te quedarías fuera."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 SSH endurecido y la fuerza bruta frenada."; exit 0; } || exit 1
