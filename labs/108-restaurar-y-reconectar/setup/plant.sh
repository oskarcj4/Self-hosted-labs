#!/usr/bin/env bash
# Planta el escenario (root): crea la tienda, hace un backup bueno, simula la
# pérdida (DROP DATABASE) y deja a la app apuntando a un "failover" inexistente.
set -e

systemctl start postgresql
for _ in $(seq 1 30); do sudo -u postgres pg_isready -q && break || sleep 1; done

# Base de datos "de producción" con datos.
sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
DROP DATABASE IF EXISTS tienda;
DROP ROLE IF EXISTS tienda;
CREATE ROLE tienda LOGIN PASSWORD 'tienda';
CREATE DATABASE tienda OWNER tienda;
SQL
sudo -u postgres psql -v ON_ERROR_STOP=1 -d tienda <<'SQL'
CREATE TABLE productos (
  id     int PRIMARY KEY,
  nombre text NOT NULL,
  precio numeric(10,2) NOT NULL
);
INSERT INTO productos
SELECT g, 'prod-'||g, (random()*100)::numeric(10,2)+1 FROM generate_series(1,240) g;
CREATE TABLE pedidos (
  id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  producto int NOT NULL REFERENCES productos(id),
  cantidad int NOT NULL,
  creado   timestamptz NOT NULL DEFAULT now()
);
INSERT INTO pedidos(producto,cantidad)
SELECT (random()*239)::int+1, (random()*5)::int+1 FROM generate_series(1,1200);
ALTER TABLE productos OWNER TO tienda;
ALTER TABLE pedidos   OWNER TO tienda;
SQL

# Backup BUENO (fechado) + backup de HOY que falló (0 bytes) + su log.
install -d -o postgres -g postgres /var/backups/tienda
sudo -u postgres pg_dump -Fc tienda -f /var/backups/tienda/tienda-2026-10-18.dump
sudo -u postgres sh -c ': > /var/backups/tienda/tienda-2026-10-19.dump'
cat > /var/backups/tienda/pg-backup.log <<'EOF'
2026-10-18 02:00  pg_dump tienda  OK   (240 productos, 1200 pedidos)
2026-10-19 02:00  pg_dump tienda  ERROR exit 1 (no space left on device) -> fichero incompleto
EOF
chown postgres:postgres /var/backups/tienda/*

# INCIDENTE: se pierde la base de producción (alguien la borró). El ROLE queda.
sudo -u postgres psql -c 'DROP DATABASE tienda;'

# En el pánico, alguien apuntó la app a un "failover" que no existe.
install -d /etc/tienda
cat > /etc/tienda/db.conf <<'EOF'
host=127.0.0.1 port=5433 dbname=tienda_dr user=tienda password=tienda
EOF

# API (el fichero ya está en /opt/app por el Dockerfile; refrescamos por si acaso).
install -D -m 0644 /opt/lab/setup/app.py /opt/app/app.py

cat > /home/analista/PISTA.txt <<'EOF'
La app (tienda-web) da 503. Mira el detalle:
   curl -s http://127.0.0.1:8080/health | jq
Backups en /var/backups/tienda/ (ojo: no todos sirven).
EOF
chown analista:analista /home/analista/PISTA.txt
echo "escenario listo."
