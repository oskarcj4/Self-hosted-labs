#!/usr/bin/env bash
# Solución automática (corre como analista): expand / backfill por lotes / contract.
set -e
P(){ psql -d tienda -v ON_ERROR_STOP=1 -qAtX "$@"; }
fase(){ echo "[$(date +%s)] $*"; }
# Las tareas de mantenimiento van con freno: que no se coman la E/S de la app.
export PGOPTIONS="-c vacuum_cost_delay=2 -c max_parallel_maintenance_workers=0"

fase expand
# 1. EXPAND: columna nueva (instantáneo, sin reescribir) + trigger que la rellena
#    en cada INSERT/UPDATE desde ya.
P <<'SQL'
SET lock_timeout = '500ms';
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS id_nuevo bigint;
CREATE OR REPLACE FUNCTION pedidos_copia_id() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.id_nuevo := NEW.id; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS pedidos_copia_id ON pedidos;
CREATE TRIGGER pedidos_copia_id BEFORE INSERT OR UPDATE ON pedidos
  FOR EACH ROW EXECUTE FUNCTION pedidos_copia_id();
SQL

fase backfill
# 2. BACKFILL por lotes cortos (cada lote bloquea pocas filas y poco tiempo).
MAX=$(P -c "SELECT max(id) FROM pedidos WHERE id < 2000000000")
LOTE=5000
for ((desde = 1; desde <= MAX; desde += LOTE)); do
  # synchronous_commit=off SÓLO en esta sesión: si se pierde un lote por un corte, se repite.
  P -c "SET synchronous_commit = off" -c "UPDATE pedidos SET id_nuevo = id WHERE id >= $desde AND id < $((desde + LOTE)) AND id_nuevo IS NULL"
  (( (desde / LOTE) % 100 == 0 )) && echo "  backfill: $desde / $MAX"
  sleep 0.1
done
P -c "UPDATE pedidos SET id_nuevo = id WHERE id >= 2000000000 AND id_nuevo IS NULL"
fase vacuum
P -c "VACUUM ANALYZE pedidos"

fase indice
# 3. Índice único y NOT NULL sin bloquear escrituras.
P -c "DROP INDEX CONCURRENTLY IF EXISTS pedidos_id_nuevo_idx"   # por si un intento anterior lo dejó inválido
P -c "CREATE UNIQUE INDEX CONCURRENTLY pedidos_id_nuevo_idx ON pedidos (id_nuevo)"
P <<'SQL'
SET lock_timeout = '500ms';
ALTER TABLE pedidos ADD CONSTRAINT pedidos_id_nuevo_nn CHECK (id_nuevo IS NOT NULL) NOT VALID;
SQL
fase validate
P -c "ALTER TABLE pedidos VALIDATE CONSTRAINT pedidos_id_nuevo_nn"   # SHARE UPDATE EXCLUSIVE: no bloquea DML

fase contract
# 4. CONTRACT: el cambio de verdad, en una transacción corta. Con lock_timeout,
#    si no consigue el bloqueo en 0,5 s se rinde (sin hacer cola delante de la app) y se reintenta.
for intento in 1 2 3 4 5 6 7 8 9 10; do
  if P <<'SQL'
BEGIN;
SET LOCAL lock_timeout = '500ms';
LOCK TABLE pedidos IN ACCESS EXCLUSIVE MODE;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET NOT NULL;           -- usa el CHECK validado: no escanea
ALTER TABLE pedidos DROP CONSTRAINT pedidos_id_nuevo_nn;
ALTER TABLE pedidos DROP CONSTRAINT pedidos_pkey;
ALTER TABLE pedidos ADD CONSTRAINT pedidos_pkey PRIMARY KEY USING INDEX pedidos_id_nuevo_idx;
ALTER SEQUENCE pedidos_id_seq AS bigint OWNED BY pedidos.id_nuevo;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET DEFAULT nextval('pedidos_id_seq');
DROP TRIGGER pedidos_copia_id ON pedidos;
ALTER TABLE pedidos DROP COLUMN id;
ALTER TABLE pedidos RENAME COLUMN id_nuevo TO id;
COMMIT;
SQL
  then echo "  contract hecho (intento $intento)"; break; fi
  sleep 1
done
P -c "DROP FUNCTION IF EXISTS pedidos_copia_id()"
P -c "\d pedidos"
P -c "SELECT data_type, max_value FROM pg_sequences WHERE sequencename = 'pedidos_id_seq'"
trafico 120
echo "solve.sh completado."
