#!/usr/bin/env bash
# Lab 147 (Mr. Robot M6): contraseñas adivinables.
# Varias cuentas tienen contraseñas del top de rockyou y SSH entra sólo con
# contraseña, sin segundo factor. El alumno endurece la política (pam_pwquality),
# obliga MFA en SSH y bloquea las cuentas débiles hasta que se reseteen.
set -e
export HOME=/root
H=/home/analista

# --- cuentas con contraseñas débiles -----------------------------------------
for u in elliot mobley romero; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
done
echo 'elliot:elliot'       | chpasswd
echo 'mobley:password123'  | chpasswd
echo 'romero:qwerty'       | chpasswd

# --- SSH: sólo contraseña, sin segundo factor (estado inseguro de partida) ----
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q '^UsePAM' /etc/ssh/sshd_config || echo 'UsePAM yes' >> /etc/ssh/sshd_config
# Dejamos KbdInteractive/AuthenticationMethods SIN tocar (por defecto, sin MFA).

# pwquality.conf de fábrica: todo comentado (sin política real).
# /etc/security/pwquality.conf ya viene así del paquete.

mkdir -p $H/ticket
cat > $H/ticket/IAM-147.txt <<'TXT'
IAM-147 · allsafe-147 · auditoría de contraseñas
La auditoría encontró 3 cuentas con contraseñas en el top de rockyou:
  - elliot   (contraseña = el propio usuario)
  - mobley   (password123)
  - romero   (qwerty)
Y SSH entra sólo con contraseña, sin segundo factor.

1. Endurece la política de contraseñas con pam_pwquality:
   - longitud mínima >= 12
   - al menos 3 clases de caracteres (minclass 3, o los *credit)
   - aplícala en /etc/pam.d/common-password (retry).
2. Exige MFA en SSH (segundo factor además de la clave/publickey):
   - /etc/pam.d/sshd usa pam_google_authenticator.so
   - sshd_config: UsePAM yes, KbdInteractiveAuthentication yes,
     AuthenticationMethods ... keyboard-interactive, PasswordAuthentication no
3. Bloquea las 3 cuentas débiles hasta que reseteen (passwd -l).
4. ~/hallazgos.txt:  cuentas_debiles=elliot,mobley,romero
TXT
chown -R analista:analista $H/ticket
echo "Lab 147 plantado."
