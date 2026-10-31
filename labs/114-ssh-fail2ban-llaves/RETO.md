# Endurecer SSH y frenar intentos repetidos

> Defensa del host · auth.log · fail2ban · SSH sólo con llave

## Escenario

`auth.log` del bastión está lleno de `Failed password` y sigue creciendo: un
bot está probando contraseñas **ahora mismo** contra `root`. sshd acepta
contraseñas y fail2ban está instalado pero parado. Ticket en
`~/ticket/INC-114.txt`.

## Objetivos

1. Con el histórico de ayer (`/var/log/auth.log.1`) cuenta los intentos
   fallidos y saca la IP que más lo intentó. Escríbelo en `~/respuestas.txt`:
   ```
   intentos=<N>
   top=<IP>
   ```
2. Activa fail2ban con la jail `[sshd]` y `maxretry = 3`, habilitado al
   arranque. El bot en vivo tiene que acabar baneado.
3. Pasa a autenticación **sólo con llave**: `PasswordAuthentication no` (y
   cierra también `KbdInteractiveAuthentication`). Antes, asegúrate de que
   `analista` puede entrar con su llave (`ssh analista@127.0.0.1`).

## Comandos que te pueden servir

```bash
grep -c "Failed password" /var/log/auth.log.1
grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
sudo tail -f /var/log/auth.log
sudo nano /etc/fail2ban/jail.local     # [sshd] enabled/maxretry...
sudo fail2ban-client status sshd
ssh-keygen -t ed25519 ; cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
sudo sshd -t ; sudo sshd -T | grep -i authentication
```

> Trampa real de Debian 12: si usas `backend = systemd`, el filtro sshd busca
> la unidad `sshd.service`, pero en Debian se llama `ssh.service` y fail2ban
> no ve nada. Aquí rsyslog está activo: `backend = auto` +
> `logpath = /var/log/auth.log` funciona. Comprueba siempre con
> `fail2ban-client status sshd` que "Total failed" sube.
>
> Orden: primero fail2ban (y ver el ban), después cerrar contraseñas.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
