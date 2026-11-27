# Resolución guiada · Lab 176

:::piensa ¿Por qué no restaurar el backup de anoche y ya está?
Perderías todo lo de esta mañana: los pedidos de antes del `DELETE` (sólo
están en el WAL) y los que entraron después. PostgreSQL escribe cada cambio
en el **WAL** (*write-ahead log*) antes de aplicarlo; con el backup base de
anoche más todo el WAL archivado desde entonces, se puede reconstruir la base
**en cualquier segundo**. Eso es PITR (*point-in-time recovery*). Y restaurar
**aparte**, en otro puerto, permite copiar sólo lo perdido sin tocar
producción.
:::

**El plan:** (1) encontrar la hora del `DELETE`, (2) montar una instancia
aparte recuperada hasta justo antes, (3) comprobarla y (4) devolver a
producción sólo las filas borradas.

## Paso 1 · ¿Cuándo fue el `DELETE`?

**Objetivo:** el segundo exacto, para parar la recuperación justo antes.

:::pista Cómo hacerlo
```bash
sudo grep -n 'DELETE FROM pedidos' /var/log/postgresql/postgresql-15-main.log
```
El servidor registra cada sentencia que modifica datos (`log_statement = 'mod'`)
y cada línea empieza por la hora.

**Qué deberías ver:** algo como `2026-11-06 10:42:13.123 UTC [...] LOG:
statement: DELETE FROM pedidos`. Tu objetivo es **un segundo antes**:
`2026-11-06 10:42:12+00`. Apúntalo:
```bash
echo 'recovery_target_time=2026-11-06 10:42:12+00' > ~/incidente/pitr.txt
```
(Usa tu hora real. `+00` es la zona horaria: UTC, igual que el log.)
:::

## Paso 2 · Una instancia aparte desde el backup

**Objetivo:** un segundo PostgreSQL, en el puerto 5433, que arranque del
backup de anoche y reproduzca el WAL hasta esa hora.

:::pista Cómo hacerlo
```bash
D=/var/lib/postgresql/restaurada
sudo cp -a /var/backups/pg/base $D
sudo cp /etc/postgresql/15/main/pg_hba.conf $D/
sudo tee $D/postgresql.conf >/dev/null <<C
port = 5433
listen_addresses = ''
unix_socket_directories = '/var/run/postgresql'
hba_file = '$D/pg_hba.conf'
restore_command = 'cp /var/lib/pg-archivo/%f %p'
recovery_target_time = '2026-11-06 10:42:12+00'
recovery_target_action = 'promote'
archive_mode = off
C
sudo touch $D/recovery.signal
sudo chown -R postgres:postgres $D && sudo chmod 700 $D
```
`cp -a` conserva dueños y permisos. En Debian, la configuración vive en
`/etc/postgresql`, así que el backup no la trae: hay que darle una mínima.

| Directiva | Qué hace |
|---|---|
| `port = 5433` | Que no choque con producción (5432). |
| `listen_addresses = ''` | No escucha en la red, sólo por el socket local: nadie se conecta a ella por error. |
| `restore_command` | Cómo conseguir cada fichero de WAL que necesite: copiarlo del archivo. `%f` es el nombre del fichero y `%p` dónde dejarlo. |
| `recovery_target_time` | Dónde parar de reproducir el WAL. |
| `recovery_target_action = 'promote'` | Al llegar, dejar de ser una copia en recuperación y aceptar escrituras. |
| `archive_mode = off` | Que esta copia no escriba en el archivo de WAL de producción. |
| `recovery.signal` | Fichero vacío cuya presencia le dice a PostgreSQL "arranca en modo recuperación". |

`chmod 700`: PostgreSQL se niega a arrancar si su directorio de datos es
accesible por otros.

Arráncala:
```bash
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D $D -l /tmp/rest.log -w start
```
`pg_ctl` arranca una instancia a mano (sin systemd), con ese directorio de
datos (`-D`) y ese log (`-l`). `-w` espera a que esté lista.
:::

## Paso 3 · Comprueba la copia

```bash
sudo tail -5 /tmp/rest.log
sudo -u postgres psql -p 5433 -d tienda -c 'SELECT pg_is_in_recovery(), count(*) FROM pedidos'
```
**Qué deberías ver:** en el log, `recovery stopping before commit of
transaction …` y `database system is ready to accept connections`; en la
consulta, `f` (ya promovida) y los pedidos que había justo antes del `DELETE`.
Si `pg_is_in_recovery` da `t`, espera unos segundos y repite.

## Paso 4 · Devuelve a producción sólo lo borrado

**Objetivo:** copiar las filas que faltan en producción, sin tocar los pedidos
que entraron después.

:::pista Cómo hacerlo
Exporta desde la copia:
```bash
sudo -u postgres psql -p 5433 -d tienda -c "\copy pedidos TO '/tmp/pedidos-recuperados.csv' CSV"
```
`\copy` es un comando de `psql` que escribe el resultado en un fichero de **tu**
máquina (a diferencia de `COPY`, que escribiría en el servidor).

Cárgalo en producción e inserta sólo los que no existen:
```bash
sudo -u postgres psql -p 5432 -d tienda -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
CREATE TEMP TABLE recuperados (LIKE pedidos);
\copy recuperados FROM '/tmp/pedidos-recuperados.csv' CSV
INSERT INTO pedidos SELECT r.* FROM recuperados r
  WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id = r.id);
COMMIT;
SELECT count(*) FROM pedidos;
SQL
```

| Pieza | Por qué |
|---|---|
| `-v ON_ERROR_STOP=1` | Si una orden falla, `psql` para en vez de seguir con las siguientes. |
| `BEGIN … COMMIT` | Todo o nada: producción nunca queda a medio cargar. |
| `CREATE TEMP TABLE … (LIKE pedidos)` | Una tabla temporal con las mismas columnas, que desaparece al cerrar la sesión. |
| `WHERE NOT EXISTS (…)` | Inserta sólo los `id` que no están. Los pedidos nuevos tienen ids mayores (la secuencia siguió avanzando), así que no chocan. |

**Qué deberías ver:** el total de producción = los recuperados + los
posteriores al `DELETE`.
```bash
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- No toques producción hasta tener los datos recuperados aparte y verificados.
- Un backup que nunca se ha restaurado no es un backup: ensaya PITR cada mes.
- Las migraciones destructivas, revisadas y dentro de una transacción que se
  pueda deshacer.
- Cuando termines, para la copia
  (`sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/restaurada stop`).

## Si te atascas

- **`recovery ended before configured recovery target was reached`:** falta
  WAL en el archivo. Mira `/tmp/rest.log`.
- **La copia ya tiene el `DELETE` aplicado:** te pasaste de hora. Para la
  instancia, borra el directorio y repite con un segundo antes. Por esto se
  restaura aparte.
- **`pg_ctl` no arranca:** `/tmp/rest.log` dice por qué. Lo más habitual: el
  directorio no es de `postgres` o no tiene permisos `700`.
