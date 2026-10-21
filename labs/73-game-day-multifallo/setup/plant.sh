#!/usr/bin/env bash
# Lab 73 (game day): tres averías independientes a la vez en app-05.
#  1) El volumen de subidas, lleno por un core dump.
#  2) PostgreSQL no arranca: errata en un ajuste de tuning.
#  3) Falta el alias db.interno en /etc/hosts (se perdió al regenerarlo).
set -e
systemctl enable --now postgresql
for _ in $(seq 1 30); do runuser -u postgres -- pg_isready -q && break; sleep 1; done
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE tienda LOGIN PASSWORD 'Tienda-2026';
CREATE DATABASE tienda OWNER tienda;
SQL
runuser -u postgres -- psql -X -q -d tienda -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE productos (id serial PRIMARY KEY, nombre text NOT NULL);
INSERT INTO productos (nombre) SELECT 'producto-' || g FROM generate_series(1, 240) g;
ALTER TABLE productos OWNER TO tienda;
SQL

id tienda >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin tienda
install -m 0755 /opt/lab/setup/tienda.py /usr/local/lib/tienda.py
mkdir -p /srv/app/uploads
mountpoint -q /srv/app/uploads || mount -t tmpfs -o size=20m,mode=0755 tmpfs /srv/app/uploads
for i in $(seq -w 1 10); do head -c 40000 /dev/urandom > /srv/app/uploads/pedido-20261019-$i.pdf; done
chown -R tienda:tienda /srv/app/uploads
cat > /etc/systemd/system/tienda.service <<'EOF'
[Unit]
Description=tienda (web)
After=network.target postgresql.service

[Service]
User=tienda
ExecStart=/usr/bin/python3 /usr/local/lib/tienda.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now tienda

# --- Las averías ---
# 1) core dump de un crash de anoche: llena el volumen de subidas.
head -c $((19 * 1024 * 1024 + 700000)) /dev/zero > /srv/app/uploads/core.tienda.4127 2>/dev/null || true
chown tienda:tienda /srv/app/uploads/core.tienda.4127
# 2) "tuning" con una errata.
cat > /etc/postgresql/15/main/conf.d/50-tuning.conf <<'EOF'
# Tuning (CHG-7301): más memoria para la caché.
shared_buffers = 256MBB
work_mem = 8MB
EOF
chown postgres:postgres /etc/postgresql/15/main/conf.d/50-tuning.conf
systemctl restart postgresql || true
# 3) /etc/hosts regenerado sin el alias local de la BD (bind mount: se reescribe en el sitio).
grep -v 'db\.interno' /etc/hosts > /tmp/hosts.new; cat /tmp/hosts.new > /etc/hosts; rm -f /tmp/hosts.new

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/GAMEDAY-73.txt <<'EOF'
GAME DAY · app-05 · simulacro SEV1 (el equipo de resiliencia ha roto cosas a propósito)
- Síntoma: http://127.0.0.1:8080/health -> "503 error interno".
- Puede haber MÁS DE UNA avería. Cuando arregles una, vuelve a mirar.
- Datos de la plataforma:
  * La BD (PostgreSQL 15) corre en esta misma máquina. La app la llama
    'db.interno', un alias local de /etc/hosts que mantiene el
    aprovisionamiento (db.interno -> 127.0.0.1).
  * Las subidas de los clientes (pedido-*.pdf) están en /srv/app/uploads.
    NO se pueden perder.
  * El cambio CHG-7301 (tuning de PostgreSQL) se aplicó anoche: quería
    shared_buffers de 256 MB.
- Al terminar: escribe el postmortem en ~/postmortem.md con estas secciones
  (encabezados '## '):  Resumen, Cronología, Impacto, Causa raíz, Acciones
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 73 plantado."
