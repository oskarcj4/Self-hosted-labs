#!/usr/bin/env bash
# pg-01 (lab 67): PostgreSQL con el "hardening" de SEC-118 aplicado a ciegas:
# escucha sólo en localhost (en conf.d, que manda sobre postgresql.conf) y una
# regla 'reject' para toda la red al final de pg_hba.conf.
set -e
id dba >/dev/null 2>&1 || useradd -m -s /bin/bash dba
echo 'dba:Guardia-2026' | chpasswd
echo 'dba ALL=(ALL) ALL' > /etc/sudoers.d/dba && chmod 0440 /etc/sudoers.d/dba
systemctl enable --now ssh

systemctl enable --now postgresql
for _ in $(seq 1 30); do runuser -u postgres -- pg_isready -q && break; sleep 1; done
runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -q <<'SQL'
CREATE ROLE informes LOGIN PASSWORD 'Informes-2026';
CREATE DATABASE ventas;
\c ventas
CREATE TABLE pedidos (id serial PRIMARY KEY, fecha date NOT NULL, total numeric(10,2) NOT NULL);
INSERT INTO pedidos (fecha, total)
  SELECT date '2026-10-01' + (g % 20), ((g * 37) % 500) + 0.99 FROM generate_series(1, 1200) g;
GRANT SELECT ON pedidos TO informes;
SQL

C=/etc/postgresql/15/main
cat > $C/conf.d/90-hardening.conf <<'EOF'
# Hardening CIS 3.1 (SEC-118): no exponer PostgreSQL a la red.
listen_addresses = 'localhost'
EOF
cat >> $C/pg_hba.conf <<'EOF'

# Hardening CIS (SEC-118): ninguna conexión de red salvo las que se autoricen arriba.
host    all             all             0.0.0.0/0               reject
EOF
chown postgres:postgres $C/conf.d/90-hardening.conf
systemctl restart postgresql

install -m 0755 /opt/node/agent.py /usr/local/lib/state-agent.py
cat > /etc/systemd/system/state-agent.service <<'EOF'
[Unit]
Description=TerminalCero: agente de estado (sólo lectura) para el validador
After=postgresql.service

[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/state-agent.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now state-agent
echo "pg-01 plantado."
