#!/usr/bin/env bash
# Lab 59: alguien borró la tabla 'pedidos' en producción. Hay un backup bueno
# de anoche, uno vacío de hoy, y 5 clientes nuevos que NO están en el backup.
set -e
systemctl enable --now postgresql
for _ in $(seq 1 30); do su postgres -c 'pg_isready -q' && break; sleep 1; done

id tienda >/dev/null 2>&1 || useradd -r -m -s /bin/bash tienda
su postgres -c "psql -q" <<'SQL'
CREATE ROLE tienda LOGIN;
CREATE DATABASE tienda OWNER tienda;
SQL
su tienda -c "psql -q -d tienda" <<'SQL'
CREATE TABLE clientes (
  id     serial PRIMARY KEY,
  nombre text NOT NULL,
  email  text NOT NULL UNIQUE
);
CREATE TABLE pedidos (
  id         serial PRIMARY KEY,
  cliente_id integer NOT NULL REFERENCES clientes(id),
  total      numeric(10,2) NOT NULL,
  creado     timestamp NOT NULL
);
CREATE INDEX pedidos_cliente_idx ON pedidos(cliente_id);
INSERT INTO clientes (nombre, email)
  SELECT 'Cliente ' || g, 'cliente' || g || '@ejemplo.com' FROM generate_series(1,500) g;
INSERT INTO pedidos (cliente_id, total, creado)
  SELECT ((g * 7) % 500) + 1, ((g * 37) % 500) + 0.99,
         timestamp '2026-01-01' + g * interval '1 hour'
  FROM generate_series(1,2000) g;
SQL

# Backups nocturnos: el de ayer bueno, el de hoy falló y quedó vacío.
mkdir -p /var/backups/pg
chown postgres:postgres /var/backups/pg && chmod 0750 /var/backups/pg
su postgres -c 'pg_dump -Fc -d tienda -f /var/backups/pg/tienda-2026-10-19.dump'
touch -d '2026-10-19 02:00' /var/backups/pg/tienda-2026-10-19.dump
su postgres -c ': > /var/backups/pg/tienda-2026-10-20.dump'
touch -d '2026-10-20 02:00' /var/backups/pg/tienda-2026-10-20.dump
cat > /var/log/pg-backup.log <<'EOF'
2026-10-19 02:00:01 backup tienda -> /var/backups/pg/tienda-2026-10-19.dump
2026-10-19 02:00:03 OK (pg_dump exit 0)
2026-10-20 02:00:01 backup tienda -> /var/backups/pg/tienda-2026-10-20.dump
2026-10-20 02:00:01 pg_dump: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  the database system is shutting down
2026-10-20 02:00:01 FAILED (pg_dump exit 1)
EOF

# Lo que pasó HOY después del backup:
su tienda -c "psql -q -d tienda" <<'SQL'
INSERT INTO clientes (nombre, email) VALUES
  ('Ana Ruiz', 'ana.ruiz@ejemplo.com'), ('Luis Gil', 'luis.gil@ejemplo.com'),
  ('Marta Sanz', 'marta.sanz@ejemplo.com'), ('Iker Vega', 'iker.vega@ejemplo.com'),
  ('Noa Prieto', 'noa.prieto@ejemplo.com');
DROP TABLE pedidos;
SQL

install -m 0755 /opt/lab/setup/tienda_web.py /usr/local/lib/tienda_web.py
cat > /etc/systemd/system/tienda-web.service <<'EOF'
[Unit]
Description=tienda-web (frontal de la tienda)
After=postgresql.service

[Service]
User=tienda
ExecStart=/usr/bin/python3 /usr/local/lib/tienda_web.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now tienda-web

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-5002.txt <<'EOF'
INC-5002 · Prioridad 1 · db-03 · tienda
11:42  Un script de "limpieza de tablas de prueba" se lanzó contra producción.
       Ejecutó: DROP TABLE pedidos;
11:45  La web da error 500.
Datos de hoy: desde el backup de anoche se han dado de alta 5 clientes
nuevos. NO se pueden perder.
Backups en /var/backups/pg/ (log: /var/log/pg-backup.log)
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 59 plantado."
