#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
BIN=/usr/lib/postgresql/15/bin
D=/var/lib/postgresql/restaurada

# 1. ¿Cuándo fue el DELETE? (log_statement = 'mod')
LINEA=$(grep -m1 'DELETE FROM pedidos' /var/log/postgresql/postgresql-15-main.log)
echo "$LINEA"
TS=$(echo "$LINEA" | awk '{print $1" "$2" "$3}')          # 2026-11-06 10:42:13.123 UTC
OBJ=$(date -u -d "$(echo "$TS" | sed 's/\.[0-9]* / /') 1 second ago" '+%Y-%m-%d %H:%M:%S+00')
echo "recovery_target_time=$OBJ" > ~/incidente/pitr.txt
cat ~/incidente/pitr.txt

# 2. Instancia aparte desde el backup base + WAL archivado.
sudo rm -rf $D
sudo cp -a /var/backups/pg/base $D
sudo cp /etc/postgresql/15/main/pg_hba.conf $D/
sudo tee $D/postgresql.conf >/dev/null <<C
port = 5433
listen_addresses = ''
unix_socket_directories = '/var/run/postgresql'
hba_file = '$D/pg_hba.conf'
restore_command = 'cp /var/lib/pg-archivo/%f %p'
recovery_target_time = '$OBJ'
recovery_target_action = 'promote'
archive_mode = off
C
sudo touch $D/recovery.signal
sudo chown -R postgres:postgres $D && sudo chmod 0700 $D
sudo -u postgres $BIN/pg_ctl -D $D -l /var/lib/postgresql/restaurada.log -w -t 120 start
for _ in $(seq 1 60); do
  [ "$(sudo -u postgres psql -p 5433 -d tienda -tAc 'SELECT pg_is_in_recovery()' 2>/dev/null)" = f ] && break; sleep 2
done
sudo -u postgres psql -p 5433 -d tienda -c "SELECT count(*), sum(total) FROM pedidos"

# 3. Devolver a producción las filas que faltan (los ids no chocan con los nuevos).
sudo -u postgres psql -p 5433 -d tienda -c "\copy pedidos TO '/tmp/pedidos-recuperados.csv' CSV"
sudo -u postgres psql -p 5432 -d tienda -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
CREATE TEMP TABLE recuperados (LIKE pedidos);
\copy recuperados FROM '/tmp/pedidos-recuperados.csv' CSV
INSERT INTO pedidos SELECT r.* FROM recuperados r
  WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id = r.id);
COMMIT;
SELECT count(*), sum(total) FROM pedidos;
SQL
echo "solve.sh completado."
