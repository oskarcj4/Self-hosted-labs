# Contraseñas adivinables

> Mr. Robot · IAM · pam_pwquality · MFA en SSH · bloqueo de cuentas

## Escenario

La auditoría de `allsafe-147` encontró 3 cuentas con contraseñas del top de
rockyou (`elliot`, `mobley`, `romero`) y, peor aún, SSH entra **sólo con
contraseña**, sin segundo factor. Una contraseña adivinable sin MFA es una
cuenta regalada.

- **pam_pwquality** rechaza contraseñas débiles al fijarlas: longitud mínima,
  variedad de caracteres, no basadas en el usuario. Se configura en
  `/etc/security/pwquality.conf` y se activa en `/etc/pam.d/common-password`.
- **MFA en SSH**: además de la clave pública o la contraseña, un segundo factor
  (TOTP con `pam_google_authenticator`). Se encadena vía
  `AuthenticationMethods` + `KbdInteractiveAuthentication`.
- Las cuentas ya comprometidas no se "arreglan" cambiando la política: hay que
  **bloquearlas** hasta que su dueño las resetee.

## Objetivos

1. Política de contraseñas con `pam_pwquality`: `minlen >= 12`, al menos 3
   clases de caracteres (`minclass 3` o los `*credit`), aplicada en
   `/etc/pam.d/common-password`.
2. MFA en SSH:
   - `/etc/pam.d/sshd` usa `pam_google_authenticator.so`.
   - `sshd_config`: `UsePAM yes`, `KbdInteractiveAuthentication yes`,
     `AuthenticationMethods ...,keyboard-interactive`, `PasswordAuthentication no`.
3. Bloquea `elliot`, `mobley` y `romero` (`passwd -l`).
4. `~/hallazgos.txt`: `cuentas_debiles=elliot,mobley,romero`.

## Comandos que te pueden servir

```bash
sudo nano /etc/security/pwquality.conf     # minlen = 12 ; minclass = 3
sudo grep -n pam_pwquality /etc/pam.d/common-password
echo 'auth required pam_google_authenticator.so nullok' | sudo tee -a /etc/pam.d/sshd
sudo nano /etc/ssh/sshd_config             # UsePAM / KbdInteractive / AuthenticationMethods / PasswordAuthentication
sudo passwd -l elliot mobley romero; sudo passwd -S elliot
sudo sshd -t                                # valida sshd_config
```

> `nullok` permite el primer login sin TOTP para que el usuario corra
> `google-authenticator` y registre su semilla; en producción se quita después.
> La política no re-evalúa contraseñas ya fijadas: por eso además se bloquea.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
