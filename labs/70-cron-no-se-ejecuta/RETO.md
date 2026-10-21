# Cron que no se ejecuta

> Operaciones · cron · /etc/cron.d · journalctl · entorno de cron

## Escenario

En `cron-01` hay cinco tareas en `/etc/cron.d/`. Todas parecen bien
programadas y ninguna hace nada. Lanzadas a mano, "funcionan". Lee
`~/ticket/PROB-7010.txt`.

Cada tarea, cuando corre, deja un latido en `/var/lib/heartbeat/<nombre>`.
En staging están programadas cada minuto, así que puedes ver el efecto de
cada arreglo enseguida.

## Objetivos

Que **cron** (no tú a mano) ejecute las cinco tareas: `limpieza`, `informe`,
`metricas`, `backup` y `sync`. Además, `backup-db` deja su log diario en
`/var/log/backup-db-AAAA-MM-DD.log`.

Cada tarea falla por un motivo **distinto**.

## Comandos que te pueden servir

```bash
ls -l /etc/cron.d/ ; cat -A /etc/cron.d/<fichero>     # cat -A enseña saltos de línea y caracteres raros
sudo journalctl -u cron -f                           # lo que cron dice (y lo que no)
ls -l --time-style=+%T /var/lib/heartbeat/
man 5 crontab                                        # formato, el sexto campo, el '%'
run-parts --test /etc/cron.d                         # qué nombres de fichero se aceptan (orientativo)
sudo env -i PATH=/usr/bin:/bin bash -c '<comando>'   # prueba el comando con el entorno de cron
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
