#!/usr/bin/env bash
# Solución del lab 107: migración ONLINE de total (céntimos int) a total_eur
# numeric, sin bloquear la tabla, con las filas nuevas sincronizadas.
# Patrón expand/contract. Cada paso toma locks cortos o ninguno.
set -e
P(){ sudo -u postgres psql -v ON_ERROR_STOP=1 -d tienda -c "$1"; }

# Nunca esperes eternamente a un lock: si no lo coges rápido, aborta y reintenta.
PSQL_LT="SET lock_timeout='3s';"

# 1) EXPAND: columna nueva, NULLABLE -> en PG es cambio de metadatos, instantáneo.
P "$PSQL_LT ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS total_eur numeric(12,2);"

# 2) Sincronía de filas NUEVAS durante el backfill (trigger). Así los pedidos
#    que entren por la API mientras rellenas NO se quedan sin total_eur.
P "CREATE OR REPLACE FUNCTION sync_total_eur() RETURNS trigger AS \$\$
   BEGIN NEW.total_eur := round(NEW.total/100.0, 2); RETURN NEW; END \$\$ LANGUAGE plpgsql;"
P "DROP TRIGGER IF EXISTS trg_total_eur ON pedidos;"
P "CREATE TRIGGER trg_total_eur BEFORE INSERT OR UPDATE OF total ON pedidos
   FOR EACH ROW EXECUTE FUNCTION sync_total_eur();"

# 3) BACKFILL por lotes (cada UPDATE es su propia transacción -> locks de fila
#    cortos, sin un ACCESS EXCLUSIVE largo que pare la tienda).
MX=$(sudo -u postgres psql -tAqX -d tienda -c "SELECT coalesce(max(id),0) FROM pedidos")
LO=0; STEP=5000
while [ "$LO" -le "$MX" ]; do
  sudo -u postgres psql -qX -d tienda -c \
    "SET lock_timeout='3s'; UPDATE pedidos SET total_eur=round(total/100.0,2)
     WHERE id>$LO AND id<=$((LO+STEP)) AND total_eur IS NULL;"
  LO=$((LO+STEP))
done

# 4) NOT NULL sin re-escaneo que bloquee: CHECK ... NOT VALID -> VALIDATE
#    (no bloquea escrituras) -> SET NOT NULL usa la constraint ya validada.
P "$PSQL_LT ALTER TABLE pedidos ADD CONSTRAINT total_eur_nn CHECK (total_eur IS NOT NULL) NOT VALID;"
P "ALTER TABLE pedidos VALIDATE CONSTRAINT total_eur_nn;"
P "$PSQL_LT ALTER TABLE pedidos ALTER COLUMN total_eur SET NOT NULL;"
P "$PSQL_LT ALTER TABLE pedidos DROP CONSTRAINT total_eur_nn;"

echo "Migración online completa."
