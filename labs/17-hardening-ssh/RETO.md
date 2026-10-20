# Lab 17 — Endurece el servidor SSH

## Escenario (tarea de hardening)

`ssh-17` salió a producción con una configuración de SSH insegura por defecto:
permite login de `root`, acepta autenticación por contraseña y tiene reenvío X11
activado. Aplica una línea base de hardening sobre `/etc/ssh/sshd_config` **sin
romper la configuración** (debe seguir pasando `sshd -t`).

## Objetivos

Edita `/etc/ssh/sshd_config` y deja, como líneas activas (sin `#`):

1. `PermitRootLogin no`
2. `PasswordAuthentication no`  *(forzar autenticación por clave pública)*
3. La configuración debe ser válida: `sudo sshd -t` sin errores.

(Extra recomendado, no obligatorio para el validador: `X11Forwarding no`,
`PermitEmptyPasswords no`, `MaxAuthTries 3`.)

## Comandos que te pueden servir

```bash
sudo nano /etc/ssh/sshd_config
grep -iE 'permitrootlogin|passwordauthentication|x11forwarding' /etc/ssh/sshd_config
sudo sshd -t && echo "config OK"          # valida la sintaxis
sudo sshd -T | grep -i permitrootlogin    # muestra el valor efectivo
```

> Cuidado: asegúrate de que las directivas quedan **sin comentar** y escritas una
> sola vez. Un `#` delante y vuelven al valor por defecto.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
