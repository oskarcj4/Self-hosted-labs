#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 147.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
PQ=/etc/security/pwquality.conf
CP=/etc/pam.d/common-password
SD=/etc/ssh/sshd_config
PS=/etc/pam.d/sshd

echo "== Lab 147 · Contraseñas adivinables — comprobación =="

# 1) pwquality: longitud mínima
ML=$($SUDO grep -E '^\s*minlen\s*=' $PQ 2>/dev/null | tail -1 | grep -oE '[0-9]+')
[ -n "$ML" ] && [ "$ML" -ge 12 ] && ok "pwquality: minlen >= 12 ($ML)." || no "pwquality.conf: minlen debe ser >= 12 y estar activo (sin comentar)."

# 2) pwquality: complejidad (minclass>=3 o >=3 *credit negativos)
MC=$($SUDO grep -E '^\s*minclass\s*=' $PQ 2>/dev/null | tail -1 | grep -oE '[0-9]+')
NEG=$($SUDO grep -cE '^\s*(d|u|l|o)credit\s*=\s*-[1-9]' $PQ 2>/dev/null)
if { [ -n "$MC" ] && [ "$MC" -ge 3 ]; } || [ "${NEG:-0}" -ge 3 ]; then
  ok "pwquality: exige al menos 3 clases de caracteres."
else
  no "pwquality.conf: exige complejidad (minclass 3, o 3 de dcredit/ucredit/lcredit/ocredit = -1)."
fi

# 3) pam_pwquality aplicado en common-password
$SUDO grep -qE '^\s*password\s+.*pam_pwquality\.so' $CP 2>/dev/null \
  && ok "common-password usa pam_pwquality.so." || no "/etc/pam.d/common-password no invoca pam_pwquality.so."

# 4) MFA en SSH
$SUDO grep -q 'pam_google_authenticator\.so' $PS 2>/dev/null \
  && ok "/etc/pam.d/sshd invoca pam_google_authenticator.so." || no "/etc/pam.d/sshd no invoca pam_google_authenticator.so."
$SUDO grep -qiE '^\s*UsePAM\s+yes' $SD 2>/dev/null \
  && ok "sshd_config: UsePAM yes." || no "sshd_config: falta UsePAM yes."
$SUDO grep -qiE '^\s*KbdInteractiveAuthentication\s+yes|^\s*ChallengeResponseAuthentication\s+yes' $SD 2>/dev/null \
  && ok "sshd_config: reto interactivo habilitado." || no "sshd_config: falta KbdInteractiveAuthentication yes."
$SUDO grep -qiE '^\s*AuthenticationMethods\s+.*keyboard-interactive' $SD 2>/dev/null \
  && ok "sshd_config: AuthenticationMethods exige segundo factor." || no "sshd_config: AuthenticationMethods debe incluir keyboard-interactive."
$SUDO grep -qiE '^\s*PasswordAuthentication\s+no' $SD 2>/dev/null \
  && ok "sshd_config: PasswordAuthentication no (sólo clave+factor)." || no "sshd_config: pon PasswordAuthentication no."

# 5) Cuentas débiles bloqueadas
for u in elliot mobley romero; do
  st=$($SUDO passwd -S "$u" 2>/dev/null | awk '{print $2}')
  [ "$st" = "L" ] && ok "Cuenta '$u' bloqueada." || no "Cuenta '$u' no está bloqueada (passwd -l)."
done

# 6) Hallazgos
DADO=$(grep -E '^cuentas_debiles=' $H/hallazgos.txt 2>/dev/null | head -1 | cut -d= -f2- | tr ', ' '\n' | grep -E '^[a-z]+$' | sort -u | paste -sd,)
[ "$DADO" = "elliot,mobley,romero" ] && ok "hallazgos: las 3 cuentas débiles listadas." || no "hallazgos.txt: cuentas_debiles=elliot,mobley,romero."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Política dura, MFA en SSH y cuentas débiles contenidas."; exit 0; } || exit 1
