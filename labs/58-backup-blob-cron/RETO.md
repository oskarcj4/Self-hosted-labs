# Backup nocturno a Blob Storage (cron a las 3 AM)

> Operaciones · cron · rclone · Azure Blob (Azurite, local) · retención

## Escenario

Una auditoría ha descubierto que `/srv/app/data` en `files-01` **no tiene
backup automático**. Hace meses alguien subía copias a mano al Blob Storage y
dejó de hacerlo. Tienes los datos de acceso y la política de backup en
`~/ticket/TAREA-202.txt`.

El storage es **Azurite**, el emulador oficial de Azure Blob Storage. Corre en
`blob-01`, en una red interna. Todo es local: nada sale de tu máquina.

## Objetivos

1. Un remote de **rclone** llamado `blob` para el usuario root
   (`/root/.config/rclone/rclone.conf`). Ese fichero lleva la clave: **600**.
2. Un script `/usr/local/bin/backup-app.sh` que:
   - empaquete `/srv/app/data` en `app-AAAAMMDD-HHMM.tar.gz`,
   - lo suba al contenedor `backups`,
   - borre del storage los backups de **más de 7 días**,
   - deje constancia en `/var/log/backup-app.log`,
   - no arranque si ya hay otra ejecución en marcha (cerrojo
     `/run/lock/backup-app.lock`),
   - termine con error si falla cualquier paso.
3. Programado **todos los días a las 03:00**, como root.
4. Que funcione **desde cron**, no sólo desde tu terminal. Cron arranca con un
   entorno mínimo (`PATH=/usr/bin:/bin`, sin tus variables).

El validador no espera a las 3 AM: revisa la programación, lanza tu script con
el entorno de cron, **descarga** el backup y lo compara con los datos.

## Comandos que te pueden servir

```bash
sudo rclone config                                  # asistente (tipo: azureblob)
sudo rclone lsl blob:backups                        # listado con fechas
sudo rclone delete --min-age 7d --dry-run blob:backups
tar czf /tmp/x.tar.gz -C /srv/app data
flock -n /run/lock/backup-app.lock -c 'echo tengo el cerrojo'
systemctl status cron
sudo env -i PATH=/usr/bin:/bin /usr/local/bin/backup-app.sh   # simula cron
```

> rclone está en `/usr/local/bin`, que **no** está en el `PATH` de cron.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
