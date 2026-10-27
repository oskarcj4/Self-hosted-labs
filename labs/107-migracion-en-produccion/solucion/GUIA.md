# Resolución guiada · Migración de datos en plena producción

:::piensa Antes de tocar nada
La tienda está viva y con tráfico. La trampa es creer que un `ALTER COLUMN ...
TYPE` es inofensivo: toma un lock `ACCESS EXCLUSIVE` que choca hasta con un
`SELECT`, así que mientras reescribe las 150k filas **toda** la tienda se cuela
a la espera. La forma correcta no cambia la columna en caliente: añade una
nueva, sincroniza las filas nuevas, rellena por lotes y pone el NOT NULL sin
re-escaneo. Patrón **expand/contract**. Pon primero k6 a correr y haz la
migración en otra pestaña: vas a *ver* la diferencia.
:::

## Paso 0 · Pon el tráfico y siente el dolor

```bash
k6 run /opt/lab/load.js          # deja esto corriendo
```
En otra pestaña, si quieres ver morir la tienda, prueba lo ingenuo y observa
`http_req_failed` dispararse:
```sql
ALTER TABLE pedidos ALTER COLUMN total TYPE numeric(12,2) USING total/100.0;  -- NO en prod
```
Luego deshazlo (o reinicia el lab) y hazlo bien.

## Paso 1 · EXPAND: columna nueva, nullable

**Pregúntate:** ¿qué cambios de esquema son baratos en PostgreSQL? Añadir una
columna **nullable**.

:::pista Cómo hacerlo
```sql
SET lock_timeout='3s';
ALTER TABLE pedidos ADD COLUMN total_eur numeric(12,2);
```
Cambio de metadatos, lock de milisegundos. Nada de `DEFAULT` volátil ni
`NOT NULL` todavía.
:::

## Paso 2 · Sincroniza las filas NUEVAS

**Pregúntate:** mientras relleno, entran pedidos. ¿Cómo evito que queden sin
`total_eur`?

:::pista Trigger (equivale a la doble escritura de la app)
```sql
CREATE OR REPLACE FUNCTION sync_total_eur() RETURNS trigger AS $$
BEGIN NEW.total_eur := round(NEW.total/100.0, 2); RETURN NEW; END $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_total_eur BEFORE INSERT OR UPDATE OF total ON pedidos
FOR EACH ROW EXECUTE FUNCTION sync_total_eur();
```
Sin esto pierdes los pedidos hechos durante la migración.
:::

## Paso 3 · BACKFILL por lotes

**Pregúntate:** ¿un `UPDATE` de 150k filas o muchos pequeños? Muchos pequeños.

:::pista Bucle, cada lote su transacción
```bash
MX=$(sudo -u postgres psql -tAqX -d tienda -c "SELECT coalesce(max(id),0) FROM pedidos")
LO=0
while [ "$LO" -le "$MX" ]; do
  sudo -u postgres psql -d tienda -c "SET lock_timeout='3s';
    UPDATE pedidos SET total_eur=round(total/100.0,2)
    WHERE id>$LO AND id<=$((LO+5000)) AND total_eur IS NULL;"
  LO=$((LO+5000))
done
```
Locks de fila cortos, sin transacción gigante que frene el autovacuum.
:::

## Paso 4 · NOT NULL sin bloquear

**Pregúntate:** ¿`SET NOT NULL` directo? Escanea toda la tabla con lock fuerte.
Hazlo por constraint.

:::pista Cómo hacerlo
```sql
ALTER TABLE pedidos ADD CONSTRAINT total_eur_nn CHECK (total_eur IS NOT NULL) NOT VALID;
ALTER TABLE pedidos VALIDATE CONSTRAINT total_eur_nn;   -- lock suave
ALTER TABLE pedidos ALTER COLUMN total_eur SET NOT NULL; -- ya no re-escanea
ALTER TABLE pedidos DROP CONSTRAINT total_eur_nn;
```
:::

## Paso 5 · Verifica

```bash
bash /opt/lab/check.sh
```
Debe confirmar: `total_eur` numeric NOT NULL, backfill correcto, una fila nueva
rellenada sola, API viva. Y k6 con `http_req_failed` casi en 0.

## Cómo actuar en una situación así

- **Expand/contract**: columna nueva → sincronía (trigger/doble escritura) →
  backfill por lotes → constraint → swap en la app → drop de la vieja.
- **Barato vs caro**: `ADD COLUMN` nullable y `DROP COLUMN` baratos;
  `ALTER TYPE` y `SET NOT NULL` directo caros.
- **`CHECK ... NOT VALID` + `VALIDATE`** convierte un lock fuerte en suave.
- **`SET lock_timeout` siempre** en DDL de producción: que tu cambio no se
  quede atascado arrastrando a toda la cola.
- **Mide con tráfico real**: lo "rápido en local" puede ser una caída en prod.

## Si te atascas

- k6 se llena de 503 → tomaste un lock fuerte (`ALTER TYPE`/`SET NOT NULL`
  directo) o un `UPDATE` único; vuelve a los lotes.
- `check.sh`: "el pedido nuevo quedó sin total_eur" → falta el trigger (paso 2).
- `check.sh`: "total_eur todavía admite NULL" → te saltaste el paso 4.
- DDL colgado → mira `pg_locks`/`pg_stat_activity` y usa `lock_timeout`.
