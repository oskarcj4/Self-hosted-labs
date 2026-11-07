# PostgreSQL: restauración a un punto en el tiempo (PITR)

> SRE · PostgreSQL · backup base · WAL · archive_command · recovery_target_time

## Escenario

Esta mañana una migración ejecutó `DELETE FROM pedidos` **sin WHERE**. Los
pedidos nuevos siguen entrando: no se puede parar producción ni volver todo
atrás (se perderían los pedidos posteriores).

Hay copias (`~/incidente/RUNBOOK.txt`):

- un **backup base** de anoche (`pg_basebackup`),
- el **WAL archivado** de forma continua desde entonces.

Conceptos:

- PostgreSQL escribe cada cambio en el **WAL** antes de aplicarlo. Backup base
  + todo el WAL posterior = poder reconstruir la base **en cualquier segundo**.
- `recovery.signal` + `restore_command` + `recovery_target_time` le dicen a
  una instancia: "arranca desde este backup, reproduce el WAL y párate aquí".
- Restaurar **aparte** (otro puerto, otro directorio) y copiar sólo lo
  perdido es más seguro que restaurar encima de producción.

## Objetivos

1. Averigua en el log de PostgreSQL cuándo se ejecutó el `DELETE`.
2. Instancia restaurada en el puerto **5433**, recuperada hasta justo antes
   del `DELETE`; `~/incidente/pitr.txt` con `recovery_target_time=...`.
3. Producción (5432) con los pedidos borrados de vuelta **y** los posteriores.
4. Producción en marcha todo el rato, con el archivo de WAL activo.

## Pistas

```bash
sudo grep -n 'DELETE' /var/log/postgresql/postgresql-15-main.log
ls /var/backups/pg/base /var/lib/pg-archivo
sudo cp -a /var/backups/pg/base /var/lib/postgresql/restaurada
# en el directorio restaurado: postgresql.conf (port, restore_command,
# recovery_target_time, recovery_target_action, hba_file) y recovery.signal
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/restaurada -l /tmp/rest.log start
sudo -u postgres psql -p 5433 -d tienda -c 'select count(*) from pedidos'
sudo -u postgres psql -p 5433 -d tienda -c "\copy pedidos TO '/tmp/p.csv' CSV"
```

El backup no trae `postgresql.conf` ni `pg_hba.conf` (en Debian viven en
`/etc/postgresql`): tendrás que darle unos mínimos.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
