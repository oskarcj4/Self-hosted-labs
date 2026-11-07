#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
V2=/opt/tienda/releases/v2

# Expandir: columna nueva, rellenada, y la vieja se queda (v1 la necesita).
rm -f $V2/migraciones/002_*.sql
cat > $V2/migraciones/002_expandir_nombre_completo.sql <<'SQL'
-- Fase EXPANDIR (v2). La columna vieja "nombre" se queda: v1 la sigue usando
-- y tiene que poder volver en cualquier momento.
ALTER TABLE clientes ADD COLUMN nombre_completo TEXT;
UPDATE clientes SET nombre_completo = nombre WHERE nombre_completo IS NULL;
-- Lo que escriba v1 (sólo "nombre") se copia también a la columna nueva.
CREATE TRIGGER clientes_sincroniza_nombre AFTER INSERT ON clientes
WHEN NEW.nombre_completo IS NULL
BEGIN
  UPDATE clientes SET nombre_completo = NEW.nombre WHERE id = NEW.id;
END;
-- Fase CONTRAER (en una release futura, cuando v1 ya no pueda volver):
--   DROP TRIGGER clientes_sincroniza_nombre; ALTER TABLE clientes DROP COLUMN nombre;
SQL

# v2 lee la columna nueva (con respaldo) y escribe en las dos.
sed -i \
  -e 's/SELECT id, nombre_completo FROM clientes/SELECT id, COALESCE(nombre_completo, nombre) FROM clientes/' \
  -e 's/INSERT INTO clientes (nombre_completo) VALUES (?)", (nombre,)/INSERT INTO clientes (nombre, nombre_completo) VALUES (?, ?)", (nombre, nombre)/' \
  $V2/app.py
grep -n 'nombre_completo' $V2/app.py

# Ensayo en esta máquina: ida, vuelta e ida otra vez.
sudo cp -p /var/lib/tienda/tienda.db /tmp/antes-del-ensayo.db
desplegar v2 && curl -s -X POST 'localhost:8080/clientes?nombre=Prueba%20v2'; echo
desplegar v1 && curl -s localhost:8080/clientes; echo
desplegar v2 && curl -s localhost:8080/clientes; echo
desplegar v1
sudo systemctl stop tienda; sudo cp -p /tmp/antes-del-ensayo.db /var/lib/tienda/tienda.db; sudo systemctl start tienda
echo "solve.sh completado."
