# Resolución guiada · Lab 176

:::piensa ¿Por qué no restaurar el backup de anoche y ya está?
Perderías los 40 pedidos de esta mañana (sólo están en el WAL) y los que
entraron después del DELETE. PITR permite elegir el segundo exacto. Y
restaurar aparte permite copiar sólo lo que falta.
:::

## Paso 1 · La hora del DELETE

:::pista Qué mirar
```bash
sudo grep -n 'DELETE FROM pedidos' /var/log/postgresql/postgresql-15-main.log
```
La línea empieza con la hora (`log_line_prefix = '%m ...'`). Tu objetivo: un
segundo antes.
:::

## Paso 2 · La instancia aparte

:::pista Cómo hacerlo
```bash
D=/var/lib/postgresql/restaurada
sudo cp -a /var/backups/pg/base $D
sudo cp /etc/postgresql/15/main/pg_hba.conf $D/
sudo tee $D/postgresql.conf <<C
port = 5433
listen_addresses = ''
hba_file = '$D/pg_hba.conf'
restore_command = 'cp /var/lib/pg-archivo/%f %p'
recovery_target_time = '2026-11-06 10:42:12+00'
recovery_target_action = 'promote'
archive_mode = off
C
sudo touch $D/recovery.signal
sudo chown -R postgres: $D && sudo chmod 700 $D
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D $D -l /tmp/rest.log start
```
`archive_mode = off` evita que la copia escriba en el archivo de producción.
:::

## Paso 3 · Devolver lo perdido

:::pista Cómo hacerlo
Exporta con `\copy ... TO` desde 5433, carga en una tabla temporal en 5432 e
inserta sólo los `id` que no existen. Los nuevos tienen ids mayores (la
secuencia siguió), así que no chocan.
:::

## Cómo actuar en una situación así

- No toques producción hasta tener los datos recuperados aparte y verificados.
- Un backup que nunca se ha restaurado no es un backup: ensaya PITR cada mes.
- Las migraciones destructivas, con revisión y en una transacción que se pueda abortar.

## Si te atascas

- "recovery ended before configured recovery target was reached": falta WAL; ¿`pg_switch_wal()`? Mira `/tmp/rest.log`.
- Si te pasas de hora, la copia ya tiene el DELETE: bórrala y repite con otra hora (por eso se restaura aparte).
