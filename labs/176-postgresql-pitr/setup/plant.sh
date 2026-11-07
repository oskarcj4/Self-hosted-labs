#!/usr/bin/env bash
# Lab 176: backup base de anoche + archivo de WAL. Esta mañana una "migración"
# ejecutó DELETE FROM pedidos sin WHERE. Después siguieron entrando pedidos.
# El alumno restaura en una instancia aparte (5433) hasta justo antes del
# DELETE y devuelve a producción las filas perdidas sin pisar las nuevas.
set -e
H=/home/analista
V=15
CONF=/etc/postgresql/$V/main
ARCH=/var/lib/pg-archivo
BK=/var/backups/pg
psqlp(){ runuser -u postgres -- psql -q -v ON_ERROR_STOP=1 "$@"; }

install -d -o postgres -g postgres -m 0750 $ARCH $BK
cat > $CONF/conf.d/archivo.conf <<C
wal_level = replica
archive_mode = on
archive_command = 'test ! -f $ARCH/%f && cp %p $ARCH/%f'
archive_timeout = 60
log_statement = 'mod'
log_line_prefix = '%m [%p] %u@%d '
C
systemctl enable --now postgresql
for _ in $(seq 1 30); do runuser -u postgres -- pg_isready -q && break; sleep 1; done

psqlp <<'SQL'
CREATE DATABASE tienda;
\c tienda
CREATE TABLE pedidos (id serial PRIMARY KEY, cliente text NOT NULL, total numeric(10,2) NOT NULL,
                      creado timestamptz NOT NULL DEFAULT now());
INSERT INTO pedidos (cliente, total)
  SELECT 'cliente-' || g, round((random() * 200 + 5)::numeric, 2) FROM generate_series(1, 120) g;
SQL

# --- Backup base de "anoche" ------------------------------------------------------
runuser -u postgres -- pg_basebackup -D $BK/base -Fp -X stream -c fast -l "backup nocturno"
psqlp -c "SELECT pg_switch_wal();" >/dev/null

# --- Pedidos de esta mañana (sólo están en el WAL) -----------------------------------
psqlp -d tienda -c "INSERT INTO pedidos (cliente, total)
  SELECT 'mañana-' || g, round((random() * 200 + 5)::numeric, 2) FROM generate_series(1, 40) g;"
sleep 3
date +%s > /opt/lab/.t_antes
sleep 3
# --- El accidente -----------------------------------------------------------------------
EXPECT=$(psqlp -d tienda -tAc "SELECT count(*) || ' ' || sum(total) FROM pedidos")
runuser -u postgres -- psql -q -d tienda -c "DELETE FROM pedidos;"   # migración 0042 sin WHERE
date +%s > /opt/lab/.t_borrado
sleep 3
# --- Después siguieron entrando pedidos ----------------------------------------------
psqlp -d tienda -c "INSERT INTO pedidos (cliente, total)
  SELECT 'despues-' || g, round((random() * 200 + 5)::numeric, 2) FROM generate_series(1, 8) g;"
NUEVOS=$(psqlp -d tienda -tAc "SELECT count(*) || ' ' || sum(total) FROM pedidos")
psqlp -c "SELECT pg_switch_wal();" >/dev/null
sleep 2
echo "$EXPECT" > /opt/lab/.perdidos; echo "$NUEVOS" > /opt/lab/.nuevos
chmod 0600 /opt/lab/.t_* /opt/lab/.perdidos /opt/lab/.nuevos

mkdir -p $H/incidente
cat > $H/incidente/ticket.txt <<'TXT'
INC-176 · Han desaparecido los pedidos

09:xx  Despliegue de la versión 4.2 con la migración 0042 ("limpiar pedidos de prueba").
       La migración tenía un DELETE sin WHERE.
       Soporte: "la lista de pedidos está vacía salvo los de hace un rato".
       Los pedidos nuevos siguen entrando: NO pares producción.
TXT
cat > $H/incidente/RUNBOOK.txt <<TXT
Copias de PostgreSQL ($V)
- Backup base nocturno (pg_basebackup, formato plano): $BK/base
- WAL archivado continuamente en:                     $ARCH
- Configuración de producción: $CONF (datos en /var/lib/postgresql/$V/main)
- Log de PostgreSQL (registra las sentencias que modifican datos):
    /var/log/postgresql/postgresql-$V-main.log
- Binarios: /usr/lib/postgresql/$V/bin (pg_ctl, postgres...)
TXT
chown -R analista:analista $H/incidente
chmod 0755 /var/log/postgresql; chmod 0644 /var/log/postgresql/*.log

cat > $H/TAREA.txt <<'TXT'
TAREA · Restauración a un punto en el tiempo (PITR)

Lee ~/incidente/ticket.txt y ~/incidente/RUNBOOK.txt.

1. Encuentra en el log de PostgreSQL CUÁNDO se ejecutó el DELETE.
2. Restaura el backup base en una instancia APARTE, en el puerto 5433, y
   recupera con el WAL archivado hasta JUSTO ANTES del DELETE.
   Apunta en ~/incidente/pitr.txt:  recovery_target_time=<la hora que usaste>
3. Devuelve a producción (puerto 5432) los pedidos borrados, SIN perder los
   que entraron después del DELETE.
4. Producción sigue en marcha todo el rato.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 176 plantado."
