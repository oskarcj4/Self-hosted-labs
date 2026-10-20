# Día 14 — PATH seguro en scripts privilegiados

> 30 días de DevSecOps · Linux · Secretos y limpieza de políticas

## Escenario

Cada noche cron ejecuta **como root** `/usr/local/sbin/backup-config.sh`, que
empaqueta `/etc/app` en `/var/backups/config`. El script llama a `tar`,
`gzip`, `date`, `mkdir` y `sha256sum` **sin ruta**, y el `PATH` de la tarea
de cron empieza por `/opt/tools/bin`… que cualquiera puede escribir.

Basta con dejar un `tar` falso en `/opt/tools/bin` para que root lo ejecute
esa noche.

## Objetivos

1. El script no debe depender del `PATH` que hereda: aunque se lance con un
   `PATH` envenenado, sólo debe ejecutar los comandos legítimos del sistema.
2. Debe seguir generando la copia (`config-*.tar.gz` con `app/app.conf` dentro).
3. El script, de root y no modificable por otros.
4. El `PATH` de `/etc/cron.d/backup-config` sólo debe contener carpetas de root
   no escribibles por otros, y `/opt/tools/bin` deja de ser escribible por todos.
5. La tarea de cron sigue programada.

## Comandos que te pueden servir

```bash
cat /usr/local/sbin/backup-config.sh /etc/cron.d/backup-config
ls -ld /opt/tools/bin
command -v tar gzip date mkdir sha256sum      # rutas absolutas reales
# Prueba de fuego (lo que hará el validador):
mkdir /tmp/evil && printf '#!/bin/sh\necho PWNED >&2\nexec /usr/bin/tar "$@"\n' > /tmp/evil/tar && chmod +x /tmp/evil/tar
sudo env PATH=/tmp/evil:/usr/bin:/bin /usr/local/sbin/backup-config.sh
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
