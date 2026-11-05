# Solución — Contraseñas adivinables

## Qué pasaba

`elliot`, `mobley` y `romero` tenían contraseñas triviales y SSH entraba sólo
con contraseña. Faltaba política (`pam_pwquality`) y segundo factor.

## Arreglo

```bash
# 1) Política de contraseñas
sudo sed -i -E 's/^#?\s*minlen\s*=.*/minlen = 12/'   /etc/security/pwquality.conf
sudo sed -i -E 's/^#?\s*minclass\s*=.*/minclass = 3/' /etc/security/pwquality.conf
grep -E 'minlen|minclass' /etc/security/pwquality.conf
# pam_pwquality ya suele estar en common-password con libpam-pwquality; si no:
grep pam_pwquality /etc/pam.d/common-password

# 2) MFA en SSH
echo 'auth required pam_google_authenticator.so nullok' | sudo tee -a /etc/pam.d/sshd
sudo sed -i -E 's/^#?\s*UsePAM.*/UsePAM yes/'                                   /etc/ssh/sshd_config
sudo sed -i -E 's/^#?\s*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i -E 's/^#?\s*PasswordAuthentication.*/PasswordAuthentication no/'    /etc/ssh/sshd_config
echo 'AuthenticationMethods publickey,keyboard-interactive' | sudo tee -a /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl restart ssh

# 3) Bloquear las cuentas comprometidas
sudo passwd -l elliot mobley romero
sudo passwd -S elliot        # elliot L ...

# 4) Hallazgos
echo 'cuentas_debiles=elliot,mobley,romero' > ~/hallazgos.txt
bash /opt/lab/check.sh
```

## Más allá del lab

- `pam_pwquality` no re-evalúa contraseñas ya puestas: combínalo con caducidad
  (`chage -M`) para forzar el cambio y que la nueva pase la política.
- MFA real: cada usuario corre `google-authenticator` para registrar su semilla
  TOTP; luego se quita `nullok` para exigir el factor siempre.
- Mejor que contraseña+TOTP: `publickey` + TOTP, y nada de password.
