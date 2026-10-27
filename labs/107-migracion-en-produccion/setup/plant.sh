#!/usr/bin/env bash
# Planta el escenario (root): arranca PostgreSQL, crea la tienda con una tabla
# 'pedidos' grande (total en céntimos), instala la API y deja el tráfico listo.
set -e

systemctl start postgresql
# Espera a que el cluster acepte conexiones.
for _ in $(seq 1 30); do
  sudo -u postgres pg_isready -q && break || sleep 1
done

sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
DROP DATABASE IF EXISTS tienda;
DROP ROLE IF EXISTS tienda;
CREATE ROLE tienda LOGIN PASSWORD 'tienda';
CREATE DATABASE tienda OWNER tienda;
SQL

sudo -u postgres psql -v ON_ERROR_STOP=1 -d tienda <<'SQL'
CREATE TABLE pedidos (
  id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cliente  text   NOT NULL,
  total    integer NOT NULL,            -- importe en CÉNTIMOS (deuda técnica)
  creado   timestamptz NOT NULL DEFAULT now()
);
-- 150k pedidos: suficiente para que un rewrite/lock de tabla se note.
INSERT INTO pedidos(cliente,total)
SELECT 'cliente-'||(g%500), (random()*20000)::int + 100
FROM generate_series(1,150000) g;
ALTER TABLE pedidos OWNER TO tienda;
GRANT ALL ON pedidos TO tienda;
SQL

# API de la tienda. NO la arrancamos aquí: shop-api.service tiene
# After=/Requires=labsetup.service y systemd la levanta sola al terminar este
# plant (arrancar otra unit desde dentro de labsetup bloquearía la transacción).
install -d /opt/app
cp /opt/lab/setup/app.py /opt/app/app.py
cp /opt/lab/setup/load.js /opt/lab/load.js

# Pista de arranque para el alumno.
cat > /home/analista/COMO-EMPEZAR.txt <<'EOF'
1) En ESTA pestaña, lanza el tráfico de usuarios:
      k6 run /opt/lab/load.js
2) Abre OTRA pestaña (menú de la plataforma) y haz ahí la migración.
3) Observa en k6 cómo http_req_failed sube si bloqueas la tabla.
EOF
chown analista:analista /home/analista/COMO-EMPEZAR.txt

echo "escenario listo."
