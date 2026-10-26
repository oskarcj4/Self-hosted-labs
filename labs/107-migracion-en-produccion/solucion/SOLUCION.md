# Solución — Migración de datos en producción (expand/contract)

## La idea

No cambies la columna en caliente. Añade una nueva, rellénala por lotes y
sincroniza las filas nuevas con un trigger. El patrón se llama
**expand/contract**: primero *expandes* (convives con las dos columnas), luego
*contraes* (retiras la vieja cuando la app ya usa la nueva).

## 1. EXPAND — columna nueva, nullable (instantáneo)

```sql
SET lock_timeout='3s';
ALTER TABLE pedidos ADD COLUMN total_eur numeric(12,2);
```

Añadir una columna **nullable** en PostgreSQL es un cambio de metadatos: no
reescribe la tabla, el lock dura milisegundos.

## 2. Sincroniza las filas nuevas (trigger)

```sql
CREATE OR REPLACE FUNCTION sync_total_eur() RETURNS trigger AS $$
BEGIN NEW.total_eur := round(NEW.total/100.0, 2); RETURN NEW; END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_total_eur BEFORE INSERT OR UPDATE OF total ON pedidos
FOR EACH ROW EXECUTE FUNCTION sync_total_eur();
```

Sin esto, los pedidos que entren mientras rellenas quedarían con `total_eur`
NULL: **pedidos perdidos** por la migración. (En un despliegue real esto suele
ser *doble escritura* desde la app; el trigger es el equivalente en la BD.)

## 3. BACKFILL por lotes

```bash
MX=$(psql -tAqX -d tienda -c "SELECT coalesce(max(id),0) FROM pedidos")
LO=0
while [ "$LO" -le "$MX" ]; do
  psql -d tienda -c "SET lock_timeout='3s';
    UPDATE pedidos SET total_eur=round(total/100.0,2)
    WHERE id>$LO AND id<=$((LO+5000)) AND total_eur IS NULL;"
  LO=$((LO+5000))
done
```

Cada lote es su **propia transacción**: locks de fila cortos, nada de un
`UPDATE` único de 150k filas que mantenga una transacción gigante y bloquee el
autovacuum. Un `sleep` entre lotes alivia aún más si la tabla es enorme.

## 4. NOT NULL sin re-escaneo bloqueante

```sql
ALTER TABLE pedidos ADD CONSTRAINT total_eur_nn CHECK (total_eur IS NOT NULL) NOT VALID;
ALTER TABLE pedidos VALIDATE CONSTRAINT total_eur_nn;   -- no bloquea escrituras
ALTER TABLE pedidos ALTER COLUMN total_eur SET NOT NULL; -- usa la constraint, sin re-escaneo largo
ALTER TABLE pedidos DROP CONSTRAINT total_eur_nn;
```

Un `SET NOT NULL` directo escanea toda la tabla con `ACCESS EXCLUSIVE`. La
constraint `NOT VALID` + `VALIDATE` hace el escaneo con un lock suave
(`SHARE UPDATE EXCLUSIVE`), y después `SET NOT NULL` ya no reescanea.

## 5. CONTRACT (fuera del lab)

Cuando la app lea y escriba `total_eur`: retira el trigger y, más tarde, haz
`ALTER TABLE pedidos DROP COLUMN total`. Dejar caer una columna es rápido (no
reescribe), pero hazlo cuando nadie la use.

## Por qué la forma ingenua mata la tienda

`ALTER COLUMN ... TYPE` reescribe la tabla entera bajo `ACCESS EXCLUSIVE`. Ese
lock entra en conflicto hasta con un `SELECT`: toda la tienda queda a la cola
hasta que la migración acaba. Con 150k filas son segundos; con millones, una
caída. `SET lock_timeout` evita además que tu DDL se quede atascado detrás de
una transacción larga y arrastre a todos los que vienen detrás.

## Lecciones

- Migra en caliente con expand/contract: columna nueva → trigger/doble
  escritura → backfill por lotes → constraint → swap → drop.
- `ADD COLUMN` nullable y `DROP COLUMN` son baratos; `ALTER TYPE` y
  `SET NOT NULL` directo son caros (reescriben/escanean con lock fuerte).
- `CHECK ... NOT VALID` + `VALIDATE` convierte un lock fuerte en uno suave.
- `SET lock_timeout` siempre en DDL de producción.
- Mide con tráfico real (k6): una migración "rápida en mi portátil" puede ser
  una caída de 10 minutos en producción.
