#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
PQ=/etc/security/pwquality.conf
SD=/etc/ssh/sshd_config
PS=/etc/pam.d/sshd

# 1) Política pwquality
sed -i -E 's/^#?\s*minlen\s*=.*/minlen = 12/'   $PQ
grep -q '^minlen' $PQ || echo 'minlen = 12' >> $PQ
sed -i -E 's/^#?\s*minclass\s*=.*/minclass = 3/' $PQ
grep -q '^minclass' $PQ || echo 'minclass = 3' >> $PQ

# 2) pam_pwquality en common-password (si no estuviera)
grep -qE '^\s*password\s+.*pam_pwquality\.so' /etc/pam.d/common-password || \
  sed -i '0,/^password/s//password\trequisite\t\t\tpam_pwquality.so retry=3\npassword/' /etc/pam.d/common-password

# 3) MFA en SSH
grep -q 'pam_google_authenticator.so' $PS || echo 'auth required pam_google_authenticator.so nullok' >> $PS
sed -i -E 's/^#?\s*UsePAM.*/UsePAM yes/' $SD; grep -q '^UsePAM' $SD || echo 'UsePAM yes' >> $SD
sed -i -E 's/^#?\s*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' $SD
grep -q '^KbdInteractiveAuthentication' $SD || echo 'KbdInteractiveAuthentication yes' >> $SD
sed -i -E 's/^#?\s*PasswordAuthentication.*/PasswordAuthentication no/' $SD
grep -q '^AuthenticationMethods' $SD || echo 'AuthenticationMethods publickey,keyboard-interactive' >> $SD

# 4) Bloquear cuentas débiles
for u in elliot mobley romero; do passwd -l "$u" >/dev/null; done

# 5) Hallazgos
echo 'cuentas_debiles=elliot,mobley,romero' > $H/hallazgos.txt
chown analista:analista $H/hallazgos.txt
echo "solve.sh completado."
