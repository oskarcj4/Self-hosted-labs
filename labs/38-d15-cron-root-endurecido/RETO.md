# Día 15 — Endurecer una tarea cron de root

> 30 días de DevSecOps · Linux · Secretos y limpieza de políticas

## Escenario

Cada 5 minutos cron ejecuta **como root** un script de limpieza de caché que
alguien dejó "de momento" en `/var/tmp/jobs/`. Tanto la carpeta como el
script son `0777`: cualquier usuario puede añadirle una línea y esperar como
mucho 5 minutos para tener root.

## Objetivos

1. El script de la tarea debe vivir en una **ubicación de sistema** (no en
   `/tmp`, `/var/tmp`, `/dev/shm` ni `/home`), con ruta absoluta.
2. El script **y todas las carpetas de su ruta** deben ser de root y no
   escribibles por grupo/otros.
3. `/etc/cron.d/cache-cleanup` debe apuntar al nuevo script y seguir siendo
   de root con permisos seguros. Ninguna tarea debe seguir apuntando a
   `/var/tmp/jobs`.
4. El script debe seguir funcionando: borra `/var/cache/app/*.tmp` y respeta
   el resto de ficheros.
5. `cron` debe seguir activo.

> Antes de copiar el script, **léelo**: estuvo escribible por todos. ¿Sigue
> haciendo sólo lo que debe?

## Comandos que te pueden servir

```bash
cat /etc/cron.d/cache-cleanup ; ls -la /var/tmp/jobs/
cat /var/tmp/jobs/cleanup-cache.sh
sudo install -m 0755 -o root -g root <origen> /usr/local/sbin/<nombre>
namei -l /usr/local/sbin/<nombre>         # dueño y permisos de cada carpeta de la ruta
sudo nano /etc/cron.d/cache-cleanup
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
