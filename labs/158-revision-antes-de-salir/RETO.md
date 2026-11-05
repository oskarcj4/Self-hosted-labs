# Revisión antes de salir

> Imagen y ejecución · go-live · seguridad · backups · runbook · rollback

## Escenario

`allsafe-api` va a producción. Antes de abrir el tráfico, toca la **revisión de
go-live**: lo que separa "lo subimos y a ver" de "lo subimos con red debajo". La
revisión encontró cinco huecos y no se sale hasta cerrarlos todos.

Un despliegue no termina cuando el código corre: termina cuando, si algo sale
mal a las 3 de la mañana, alguien sabe qué hacer y puede volver atrás en minutos.

## Objetivos (ciérralos y marca `~/checklist.txt`)

1. **Seguridad**: el servicio no debe correr como root. Ponlo como `appuser`
   (`User=appuser` en el unit) y reinícialo.
2. **Secreto**: `/etc/allsafe/secret.env` a permisos `600`.
3. **Backups**: `/usr/local/bin/backup.sh`, un timer `allsafe-backup` habilitado,
   y un backup de prueba en `/var/backups/allsafe`.
4. **Runbook**: `/opt/allsafe/RUNBOOK.md` con secciones `## Despliegue`,
   `## Rollback` y `## Contacto`.
5. **Rollback**: `/usr/local/bin/rollback.sh` ejecutable.

Al final: marca los 5 puntos con `[x]` en `~/checklist.txt` y pon `Aprobado por:`.

## Pistas

```bash
sudo systemctl edit allsafe-api        # añade [Service]\nUser=appuser
sudo systemctl show allsafe-api -p User
sudo chmod 600 /etc/allsafe/secret.env
systemd-analyze calendar daily          # entender OnCalendar
sudo systemctl enable allsafe-backup.timer
```

> La revisión no es burocracia: cada punto es una pregunta que te harás en el
> peor momento. Respóndelas ahora, con calma.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
