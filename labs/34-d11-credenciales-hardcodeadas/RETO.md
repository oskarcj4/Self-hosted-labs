# Día 11 — Quitar credenciales hardcodeadas

> 30 días de DevSecOps · Linux · Secretos y limpieza de políticas

## Escenario

Cada noche cron ejecuta `/opt/maint/db-maintenance.sh` como root para hacer
mantenimiento de la base de datos de pedidos. El script tiene la contraseña
de la BD **escrita dentro** y es legible por cualquier usuario. Además, en
la misma carpeta hay una copia de respaldo que nadie recuerda.

## Objetivos

1. Saca las credenciales del script a **`/etc/maint/db.cred`**, de `root` y
   sin permisos para grupo ni otros (`0600` o `0400`).
2. El script debe cargar las credenciales desde ese fichero y **no** contener
   la contraseña.
3. No debe quedar la contraseña en ningún otro sitio legible (copias, logs…).
4. El script debe seguir funcionando: `sudo /opt/maint/db-maintenance.sh` →
   `VACUUM OK`. Debe seguir siendo de root y no modificable por otros.
5. La tarea de cron (`/etc/cron.d/db-maint`) debe seguir lanzándolo.

## Comandos que te pueden servir

```bash
cat /opt/maint/db-maintenance.sh ; ls -la /opt/maint/
sudo grep -rlF 'DB_PASSWORD' /opt /etc /home 2>/dev/null
sudo install -d -m 0700 /etc/maint
sudo install -m 0600 /dev/null /etc/maint/db.cred     # crea vacío con permisos correctos
sudo nano /etc/maint/db.cred
# dentro del script:   . /etc/maint/db.cred   (o: source)
sudo /opt/maint/db-maintenance.sh
```

> Crea el fichero **ya** con permisos cerrados: si lo escribes primero y le
> haces `chmod` después, durante unos segundos la contraseña es pública.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
