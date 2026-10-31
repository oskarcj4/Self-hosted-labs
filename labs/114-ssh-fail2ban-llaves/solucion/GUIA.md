# Resolución guiada · Lab 114

:::piensa Antes de tocar nada
Dos defensas con orden: fail2ban necesita ver "Failed password" para banear;
quitar las contraseñas cierra la puerta del todo. Y antes de cerrar las
contraseñas, asegúrate de que tú entras con llave.
:::

## Paso 1 · ¿Cuánto ataque hay?

**Pregúntate:** ¿cuántos intentos fallidos hubo y qué IP es la que más insiste?

:::pista Cómo comprobarlo
```bash
sudo grep -c "Failed password" /var/log/auth.log.1
sudo grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
```
Escribe `intentos=` y `top=` en `~/respuestas.txt`.
:::

## Paso 2 · fail2ban

**Pregúntate:** ¿dónde se configura fail2ban sin que una actualización pise tus cambios?

:::pista Cómo hacerlo
```bash
sudo tee /etc/fail2ban/jail.local <<'J'
[sshd]
enabled  = true
backend  = auto
logpath  = /var/log/auth.log
maxretry = 3
findtime = 10m
bantime  = 1h
J
sudo systemctl enable --now fail2ban; sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```
`backend = auto` + `logpath`: el contenedor escribe en `auth.log`, no en el journal.
:::

## Paso 3 · Tu llave antes de cerrar

**Pregúntate:** si desactivas contraseñas ahora, ¿cómo entras tú?

:::pista Cómo hacerlo
```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys
ssh -o PasswordAuthentication=no analista@localhost true && echo "la llave funciona"
```
:::

## Paso 4 · Sólo llaves

**Pregúntate:** ¿qué ficheros lee sshd y cuál gana si una opción aparece dos veces?

:::pista Cómo hacerlo
```bash
sudo tee /etc/ssh/sshd_config.d/10-solo-llave.conf <<'C'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
C
sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -E 'passwordauth|permitroot'
```
En sshd gana el **primer** valor leído; los `.d/` se incluyen al principio.
:::

## Cómo actuar en una situación así

- **Primero la llave, luego cerrar contraseñas**, con otra sesión abierta por si acaso.
- **`sshd -t` antes de recargar**; `sshd -T` para ver la configuración efectiva.
- fail2ban reduce ruido; las llaves eliminan el riesgo de contraseñas débiles.

## Si te atascas

- fail2ban no banea: `fail2ban-client status sshd` muestra "File list"; si está vacío, falta `logpath`.
- `sshd -T` sigue diciendo `passwordauthentication yes`: otra línea anterior lo fija; búscala con `grep -r Password /etc/ssh/`.
