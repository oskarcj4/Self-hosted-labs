# Resolución guiada · Lab 20

:::piensa Antes de tocar nada
fail2ban hace lo que tú hiciste a mano en el lab 14, pero solo y siempre: **lee logs, cuenta fallos por IP y banea** a quien supera un límite. Configurarlo es responder: ¿qué log leo?, ¿cuántos fallos?, ¿en cuánto tiempo?, ¿cuánto dura el baneo?
:::

## Paso 1 · Mira el ataque

**Pregúntate:** antes de automatizar, ¿quién está atacando y cuánto?

:::pista Cómo comprobarlo
```bash
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn
```
:::

## Paso 2 · Configura sin tocar el original

**Pregúntate:** ¿por qué `jail.local` y no `jail.conf`? Porque `jail.conf` lo sobrescriben las actualizaciones; `jail.local` es tuyo y tiene prioridad.

:::pista Plantilla comentada
```ini
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
backend  = polling

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
```
- `bantime`: cuánto dura el baneo.
- `findtime`: ventana en la que se cuentan los fallos.
- `maxretry`: fallos permitidos dentro de esa ventana.
- `backend = polling`: leer el fichero de log directamente.

Guárdala con `sudo tee /etc/fail2ban/jail.local`.
:::

## Paso 3 · Arranca y comprueba que te escucha

:::pista Cómo hacerlo
```bash
sudo fail2ban-client start      # o reload si ya estaba corriendo
sudo fail2ban-client ping       # Server replied: pong
sudo fail2ban-client status sshd
```
Si `status sshd` falla, la jail no se cargó: revisa la sintaxis del `.local`.
:::

## Paso 4 · Contén ya al atacante conocido

**Pregúntate:** fail2ban actúa sobre intentos **nuevos**. ¿Qué hago con quien ya atacó antes de que lo instalara? Banearlo a mano.

:::pista Cómo hacerlo
```bash
sudo fail2ban-client set sshd banip <IP>
sudo fail2ban-client status sshd
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **`ignoreip`** para tus IPs de administración: un baneo a ti mismo en remoto es un mal día.
- **fail2ban complementa, no sustituye**: sin contraseñas (lab 17) la fuerza bruta ya no funciona; fail2ban reduce el ruido.
- **Revisa periódicamente** `fail2ban-client status sshd`: cuántos baneos y de dónde.

## Si te atascas

- `start` dice que ya corre: usa `reload`.
- La IP no aparece en la lista: comprueba que usaste la jail `sshd` en `banip`.
