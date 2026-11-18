# Resolución guiada · Lab 220

:::piensa ¿Por qué no basta con `ALTER TABLE pedidos ALTER COLUMN id TYPE bigint`?
Cambiar de `integer` a `bigint` cambia el tamaño en disco. PostgreSQL
**reescribe la tabla entera** y reconstruye sus índices. Mientras tanto tiene
un bloqueo `ACCESS EXCLUSIVE`: nadie puede ni leer. Con 3 M filas son más de
10 s, y la app (con `lock_timeout = 1s`) devuelve errores todo ese tiempo.
Pruébalo y mira `trafico 60`. Luego ejecuta `sudo reiniciar-tienda`.
:::

## Paso 1 · Expand: columna nueva y trigger

:::pista Cómo hacerlo
```sql
SET lock_timeout = '500ms';
ALTER TABLE pedidos ADD COLUMN id_nuevo bigint;      -- sin default: instantáneo
CREATE FUNCTION pedidos_copia_id() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.id_nuevo := NEW.id; RETURN NEW; END $$;
CREATE TRIGGER pedidos_copia_id BEFORE INSERT OR UPDATE ON pedidos
  FOR EACH ROW EXECUTE FUNCTION pedidos_copia_id();
```
Desde ahora, toda fila nueva o modificada ya trae `id_nuevo`.
:::

:::piensa ¿Para qué el `lock_timeout` en TU sesión?
`ADD COLUMN` necesita un bloqueo breve. Si espera porque otra transacción tiene
la tabla, **todas** las consultas de la app hacen cola detrás de él. Con
`lock_timeout`, tu DDL se rinde rápido en vez de tumbar la tienda. Luego
puedes reintentarlo.
:::

## Paso 2 · Backfill por lotes

:::pista Cómo hacerlo
```bash
for ((d = 1; d <= 3000000; d += 5000)); do
  psql tienda -c "SET synchronous_commit = off" \
    -c "UPDATE pedidos SET id_nuevo = id WHERE id >= $d AND id < $((d+5000)) AND id_nuevo IS NULL"
  sleep 0.1
done
psql tienda -c "UPDATE pedidos SET id_nuevo = id WHERE id_nuevo IS NULL"   # los recientes
psql tienda -c "VACUUM ANALYZE pedidos"
```
:::

:::piensa ¿Por qué lotes y no un único UPDATE?
Un `UPDATE` bloquea cada fila que toca hasta el `COMMIT`. Con 3 M filas en una
sola transacción, la app no puede actualizar **ningún** pedido durante
decenas de segundos. Además genera un pico enorme de WAL y de filas muertas.
Con lotes de 5 000, cada bloqueo dura milisegundos. El `sleep` deja respirar a
la E/S.
:::

## Paso 3 · Índice y NOT NULL sin bloquear

:::pista Cómo hacerlo
```sql
CREATE UNIQUE INDEX CONCURRENTLY pedidos_id_nuevo_idx ON pedidos (id_nuevo);
ALTER TABLE pedidos ADD CONSTRAINT pedidos_id_nuevo_nn CHECK (id_nuevo IS NOT NULL) NOT VALID;
ALTER TABLE pedidos VALIDATE CONSTRAINT pedidos_id_nuevo_nn;
```
`CONCURRENTLY` no bloquea escrituras. Si falla, deja un índice **inválido**:
bórralo con `DROP INDEX CONCURRENTLY` y repite. `VALIDATE CONSTRAINT` recorre
la tabla con un bloqueo que no impide leer ni escribir.
:::

## Paso 4 · Contract: el cambio final, en milisegundos

:::pista Cómo hacerlo
```sql
BEGIN;
SET LOCAL lock_timeout = '500ms';
LOCK TABLE pedidos IN ACCESS EXCLUSIVE MODE;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET NOT NULL;   -- usa el CHECK validado: no escanea
ALTER TABLE pedidos DROP CONSTRAINT pedidos_id_nuevo_nn;
ALTER TABLE pedidos DROP CONSTRAINT pedidos_pkey;
ALTER TABLE pedidos ADD CONSTRAINT pedidos_pkey PRIMARY KEY USING INDEX pedidos_id_nuevo_idx;
ALTER SEQUENCE pedidos_id_seq AS bigint OWNED BY pedidos.id_nuevo;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET DEFAULT nextval('pedidos_id_seq');
DROP TRIGGER pedidos_copia_id ON pedidos;
ALTER TABLE pedidos DROP COLUMN id;
ALTER TABLE pedidos RENAME COLUMN id_nuevo TO id;
COMMIT;
```
Si falla por `lock timeout`, repítelo. Ninguna de estas órdenes reescribe la
tabla, así que el bloqueo dura milisegundos.
:::

:::piensa ¿Por qué el orden del `OWNED BY` importa?
La secuencia pertenece a la columna `id`. Si borras `id` sin moverla antes a
`id_nuevo`, `DROP COLUMN` **borra también la secuencia**, y los ids volverían
a empezar.
:::

## Paso 5 · Comprueba

```bash
psql tienda -c '\d pedidos'
trafico 300
bash /opt/lab/check.sh
```
