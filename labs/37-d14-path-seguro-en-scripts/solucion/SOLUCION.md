# Solución — Día 14: PATH seguro en scripts privilegiados

## 1. Reproducir el ataque

```bash
ls -ld /opt/tools/bin                  # drwxrwxrwx
mkdir -p /tmp/evil
printf '#!/bin/sh\necho "PWNED como $(id -un)" >&2\nexec /usr/bin/tar "$@"\n' > /tmp/evil/tar
chmod +x /tmp/evil/tar
sudo env PATH=/tmp/evil:/usr/bin:/bin /usr/local/sbin/backup-config.sh
# PWNED como root
```

(Un atacante haría lo mismo dejando `tar` en `/opt/tools/bin` y esperando a las 2:00.)

## 2. El script fija su propio PATH

Añadir justo después del shebang:

```bash
sudo sed -i '1a\
# No confiar en el PATH heredado (cron, sudo, otro script...)\
PATH=/usr/sbin:/usr/bin:/sbin:/bin\
export PATH' /usr/local/sbin/backup-config.sh
sudo chown root:root /usr/local/sbin/backup-config.sh
sudo chmod 0755 /usr/local/sbin/backup-config.sh
```

Alternativa equivalente: rutas absolutas (`/usr/bin/tar`, `/usr/bin/gzip`…).
Fijar `PATH` al principio es más difícil de olvidar cuando el script crece.

## 3. Cerrar la carpeta y el PATH de cron

```bash
sudo chown -R root:root /opt/tools
sudo chmod 0755 /opt/tools /opt/tools/bin
sudo chmod 0755 /opt/tools/bin/s3sync
sudo sed -i 's#^PATH=.*#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#' /etc/cron.d/backup-config
```

## 4. Verificar

```bash
sudo env PATH=/tmp/evil:/usr/bin:/bin /usr/local/sbin/backup-config.sh   # sin PWNED
sudo ls -t /var/backups/config | head -2
```

## Lecciones

- Un script privilegiado **define su entorno**: `PATH`, `umask`, `IFS`, `LC_ALL`.
- El orden del `PATH` importa: la primera carpeta gana. Nunca pongas delante
  una carpeta que pueda escribir alguien que no sea root.
- `sudo` ya usa `secure_path`, pero cron, systemd timers o scripts que se llaman
  entre sí heredan lo que les den.
