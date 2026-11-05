# Resolución guiada · Lab 147

:::piensa Tres frentes
Política (que no se pongan contraseñas débiles), factor (que la contraseña no
baste) y contención (las cuentas ya débiles, fuera hasta reset). Los tres, o no
sirve.
:::

## Paso 1 · Endurece pwquality

:::pista Cómo hacerlo
```bash
sudo nano /etc/security/pwquality.conf
#   minlen = 12
#   minclass = 3
grep pam_pwquality /etc/pam.d/common-password     # debe invocarlo
```
:::

## Paso 2 · Segundo factor en SSH

**Pregúntate:** ¿qué encadena "clave pública + código TOTP" en una sola sesión?

:::pista Cómo hacerlo
```bash
echo 'auth required pam_google_authenticator.so nullok' | sudo tee -a /etc/pam.d/sshd
sudo nano /etc/ssh/sshd_config
#   UsePAM yes
#   KbdInteractiveAuthentication yes
#   AuthenticationMethods publickey,keyboard-interactive
#   PasswordAuthentication no
sudo sshd -t
```
:::

## Paso 3 · Contén lo ya comprometido

:::pista Cómo hacerlo
```bash
sudo passwd -l elliot mobley romero
sudo passwd -S elliot        # estado L (locked)
echo 'cuentas_debiles=elliot,mobley,romero' > ~/hallazgos.txt
```
:::

## Cómo actuar en una situación así

- La política previene lo nuevo; el bloqueo neutraliza lo viejo. No confundas.
- MFA sólo con contraseña sigue siendo frágil: migra a `publickey` + TOTP.

## Si te atascas

- `sshd -t` se queja de `AuthenticationMethods`: debe ir en el contexto global
  o dentro de un `Match`, con los métodos separados por coma.
- `passwd -S` no muestra `L`: usaste `-e`/`chage` en vez de `-l`.
