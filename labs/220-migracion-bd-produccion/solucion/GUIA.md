# Resolución guiada · Lab 220

:::piensa ¿Por qué no basta con `ALTER COLUMN id TYPE bigint`?
Pasar de `integer` (4 bytes) a `bigint` (8 bytes) cambia el tamaño de cada
fila. PostgreSQL **reescribe la tabla entera** y reconstruye sus índices, y
durante todo ese tiempo tiene un bloqueo `ACCESS EXCLUSIVE`: nadie puede ni
leer. Con 3 M filas son más de 10 s, y la app, que sólo espera 1 s por un
bloqueo (`lock_timeout`), devuelve errores todo ese rato.

La solución es no cambiar la columna, sino **construir una nueva al lado**,
poco a poco y sin bloquear, y cambiar una por otra en un instante. Es el
patrón *expand / contract*.
:::

**El plan:** (1) ver el problema, (2) *expand*: columna nueva y trigger,
(3) rellenarla por lotes, (4) índice y `NOT NULL` sin bloquear y
(5) *contract*: el cambio final en milisegundos.

Todo el SQL se ejecuta dentro de `psql`, el cliente de PostgreSQL. Ábrelo con
`psql tienda` (eres superusuario) y pega los bloques ahí. Sales con `\q`.

## Paso 1 · Mira el problema (y por qué no hacerlo a lo bruto)

**Objetivo:** entender el punto de partida y qué pasa con el tráfico.

:::pista Cómo hacerlo
```bash
cat ~/TAREA.txt
trafico 30
psql tienda -c '\d pedidos'
psql tienda -c "SELECT last_value FROM pedidos_id_seq"
```
- `trafico 30` es un comando del lab: resume las operaciones de la app de los
  últimos 30 s y cuántas fallaron.
- `\d pedidos` es un atajo de `psql`: describe la tabla (columnas, tipos,
  índices, *defaults*).
- La secuencia `pedidos_id_seq` es el contador que da el siguiente `id`.

**Qué deberías ver:** `id integer`, la clave primaria `pedidos_pkey` y una
secuencia por encima de 2 146 millones, a un paso del máximo de `integer`
(2 147 483 647). Fíjate en algo: los 3 M pedidos históricos tienen ids del 1
al 3 000 000, y los pedidos nuevos, ids de más de 2 146 millones.

Si quieres verlo fallar, ejecuta el `ALTER TABLE pedidos ALTER COLUMN id TYPE
bigint;` directo y mira `trafico 60`: cientos de errores. Después
`sudo reiniciar-tienda` deja la base como al principio y los contadores a 0.
:::

## Paso 2 · Expand: columna nueva y trigger

**Objetivo:** tener una columna `bigint` que, desde ya, se rellena sola en
cada fila nueva o modificada.

:::pista Cómo hacerlo
```sql
SET lock_timeout = '500ms';
ALTER TABLE pedidos ADD COLUMN id_nuevo bigint;
CREATE FUNCTION pedidos_copia_id() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.id_nuevo := NEW.id; RETURN NEW; END $$;
CREATE TRIGGER pedidos_copia_id BEFORE INSERT OR UPDATE ON pedidos
  FOR EACH ROW EXECUTE FUNCTION pedidos_copia_id();
```

| Pieza | Qué hace |
|---|---|
| `ADD COLUMN id_nuevo bigint` | Sin `DEFAULT`, PostgreSQL sólo apunta en el catálogo que la columna existe: no toca ninguna fila. Es instantáneo. |
| `CREATE FUNCTION … plpgsql` | Una función en el lenguaje de procedimientos de PostgreSQL. `NEW` es la fila que se está insertando o modificando; le copiamos `id` en `id_nuevo`. |
| `$$ … $$` | Delimitadores del cuerpo de la función: todo lo que hay entre ellos es código, sin tener que escapar comillas. |
| `BEFORE INSERT OR UPDATE … FOR EACH ROW` | La función se ejecuta antes de guardar cada fila insertada o modificada. Así ninguna fila nueva se queda sin `id_nuevo` mientras rellenas las antiguas. |
:::

:::piensa ¿Para qué el `lock_timeout` en TU sesión?
Hasta `ADD COLUMN` necesita un bloqueo, aunque sea un instante. Si al pedirlo
otra transacción tiene la tabla, tu `ALTER` espera… y **todas** las consultas
de la app se ponen en cola detrás de él. Con `lock_timeout = '500ms'`, si no
consigue el bloqueo en medio segundo se rinde con un error, la cola se
deshace y puedes repetirlo. Un error tuyo es mejor que una caída de la tienda.
:::

## Paso 3 · Rellenar por lotes

**Objetivo:** copiar `id` en `id_nuevo` en las 3 M filas antiguas sin bloquear
a la app.

**Pregúntate:** un `UPDATE` bloquea cada fila que toca hasta que termina la
transacción. ¿Qué pasa si una sola transacción toca 3 M filas?

:::pista Cómo hacerlo
Que la app no puede modificar **ningún** pedido hasta que termine, decenas de
segundos. Por eso se hace en lotes pequeños, cada uno en su propia
transacción. Esto se ejecuta desde la terminal, **fuera** de `psql`:
```bash
for ((d = 1; d <= 3000000; d += 5000)); do
  psql tienda -q -c "SET synchronous_commit = off" \
    -c "UPDATE pedidos SET id_nuevo = id WHERE id >= $d AND id < $((d + 5000)) AND id_nuevo IS NULL"
  sleep 0.1
done
psql tienda -c "UPDATE pedidos SET id_nuevo = id WHERE id >= 2000000000 AND id_nuevo IS NULL"
psql tienda -c "VACUUM ANALYZE pedidos"
```

| Pieza | Por qué |
|---|---|
| `for ((d = 1; …; d += 5000))` | Bucle de bash: `d` va de 5 000 en 5 000. Cada vuelta actualiza un rango de ids. |
| `WHERE id >= $d AND id < $((d+5000))` | Un rango de la clave primaria: PostgreSQL lo encuentra con el índice, sin recorrer la tabla. Cada lote bloquea 5 000 filas durante milisegundos. |
| `AND id_nuevo IS NULL` | Salta las filas que ya tienen valor (el trigger ya rellenó las modificadas). Si el bucle se corta, puedes relanzarlo sin repetir trabajo. |
| `SET synchronous_commit = off` | Sólo en esta sesión: no espera a que cada lote se escriba en disco para confirmar. Si el servidor cae, se pierde algún lote, pero el `IS NULL` hace que se repita. **Nunca** en la sesión de la app. |
| `sleep 0.1` | Deja respirar al disco entre lotes para que la app no note el trabajo. |
| `id >= 2000000000` | Los pedidos nuevos (ids de más de 2 146 millones) que se crearon **antes** del trigger. Son pocos, y el rango de la clave los encuentra rápido. |
| `VACUUM ANALYZE` | Cada `UPDATE` deja una versión vieja de la fila. `VACUUM` recupera ese espacio y `ANALYZE` actualiza las estadísticas del planificador. |

Tarda unos minutos. Comprueba que no falta ninguna:
```bash
psql tienda -c "SELECT count(*) FROM pedidos WHERE id_nuevo IS NULL"
```
**Qué deberías ver:** `0`.
:::

## Paso 4 · Índice y `NOT NULL` sin bloquear

**Objetivo:** preparar todo lo que necesitará la nueva clave primaria (un
índice único y la garantía de que no hay nulos) sin bloquear escrituras.

:::pista Cómo hacerlo
Dentro de `psql tienda`:
```sql
CREATE UNIQUE INDEX CONCURRENTLY pedidos_id_nuevo_idx ON pedidos (id_nuevo);
SET lock_timeout = '500ms';
ALTER TABLE pedidos ADD CONSTRAINT pedidos_id_nuevo_nn CHECK (id_nuevo IS NOT NULL) NOT VALID;
RESET lock_timeout;
ALTER TABLE pedidos VALIDATE CONSTRAINT pedidos_id_nuevo_nn;
```

| Pieza | Qué hace |
|---|---|
| `CREATE INDEX CONCURRENTLY` | Construye el índice en varias pasadas sin bloquear escrituras. Tarda más que uno normal, pero la app ni lo nota. No puede ir dentro de un `BEGIN … COMMIT`. |
| `CHECK (…) NOT VALID` | Crea la restricción **sin comprobar las filas existentes** (instantáneo). Desde ya, las filas nuevas sí deben cumplirla. |
| `VALIDATE CONSTRAINT` | Comprueba las filas existentes con un bloqueo suave que no impide leer ni escribir. |

Este `CHECK` validado es un truco: en el paso 5, `SET NOT NULL` lo verá y
sabrá que no hay nulos **sin** tener que recorrer la tabla bloqueada.

Si `CREATE INDEX CONCURRENTLY` falla a medias, deja un índice **inválido**
(`\d pedidos` lo marca como `INVALID`). Bórralo con
`DROP INDEX CONCURRENTLY pedidos_id_nuevo_idx;` y repite.
:::

## Paso 5 · Contract: el cambio final, en milisegundos

**Objetivo:** que `id_nuevo` pase a ser `id`, con su clave primaria y su
secuencia, en una sola transacción muy corta.

:::pista Cómo hacerlo
Dentro de `psql tienda`, todo el bloque de una vez:
```sql
BEGIN;
SET LOCAL lock_timeout = '500ms';
LOCK TABLE pedidos IN ACCESS EXCLUSIVE MODE;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET NOT NULL;
ALTER TABLE pedidos DROP CONSTRAINT pedidos_id_nuevo_nn;
ALTER TABLE pedidos DROP CONSTRAINT pedidos_pkey;
ALTER TABLE pedidos ADD CONSTRAINT pedidos_pkey PRIMARY KEY USING INDEX pedidos_id_nuevo_idx;
ALTER SEQUENCE pedidos_id_seq AS bigint OWNED BY pedidos.id_nuevo;
ALTER TABLE pedidos ALTER COLUMN id_nuevo SET DEFAULT nextval('pedidos_id_seq');
DROP TRIGGER pedidos_copia_id ON pedidos;
ALTER TABLE pedidos DROP COLUMN id;
ALTER TABLE pedidos RENAME COLUMN id_nuevo TO id;
COMMIT;
DROP FUNCTION pedidos_copia_id();
```

| Pieza | Por qué |
|---|---|
| `BEGIN … COMMIT` | Todo o nada: la app ve la tabla vieja o la nueva, nunca algo a medias. |
| `SET LOCAL lock_timeout` | Como antes, pero sólo dentro de esta transacción (`LOCAL`). |
| `LOCK TABLE … ACCESS EXCLUSIVE` | Pide el bloqueo fuerte **una vez, al principio**. Las órdenes siguientes ya lo tienen y no hacen cola. |
| `SET NOT NULL` | Gracias al `CHECK` validado, no recorre la tabla. |
| `PRIMARY KEY USING INDEX` | Convierte el índice único que ya construiste en la clave primaria, sin crear otro. |
| `ALTER SEQUENCE … AS bigint OWNED BY pedidos.id_nuevo` | La secuencia pasa a `bigint` (su máximo sube a 9,2 trillones) y pasa a "pertenecer" a la columna nueva. |
| `DROP COLUMN id` + `RENAME` | La columna vieja desaparece y la nueva toma su nombre. Ninguna de las dos órdenes reescribe la tabla. |

**El orden de `OWNED BY` importa:** una secuencia que pertenece a una columna
se borra con ella. Si borras `id` antes de pasar la secuencia a `id_nuevo`,
pierdes la secuencia y los ids volverían a empezar.

**Si falla por `lock timeout`:** la transacción queda abortada y `psql` muestra
el prompt como `tienda=!#`. Escribe `ROLLBACK;` y vuelve a pegar el bloque
entero. No ha cambiado nada: era todo o nada.
:::

## Paso 6 · Comprueba

```bash
psql tienda -c '\d pedidos'
trafico 300
bash /opt/lab/check.sh
```
**Qué deberías ver:** `id bigint not null default nextval(…)`, la clave
primaria en `id`, ni rastro de `id_nuevo` ni del trigger, y `trafico 300`
con 0 errores.

## Cómo actuar en una situación así

- **Expand / contract** sirve para cualquier cambio de esquema incompatible:
  renombrar columnas, partir una en dos, cambiar tipos. Primero conviven las
  dos formas, luego se migran los datos y al final se quita la vieja.
- Si otras tablas tienen **claves foráneas** a `pedidos.id`, sus columnas
  también pasan a `bigint` con el mismo método, y las FK se recrean con
  `NOT VALID` + `VALIDATE`.
- Herramientas como `pgroll`, `pg-osc` o `reshape` automatizan este patrón.
- **Prevención:** crea las claves como `bigint` desde el principio. Son 4
  bytes más por fila; migrar después cuesta mucho más.

## Si te atascas

- **El check dice que hubo errores:** algún paso bloqueó más de 1 s. Los
  sospechosos: un `UPDATE` sin lotes, un `CREATE INDEX` sin `CONCURRENTLY` o
  un `ALTER` sin `lock_timeout`. `sudo reiniciar-tienda` y repite.
- **`ERROR: cannot drop sequence … because column id requires it`** o la
  secuencia desaparece: el `OWNED BY` no se ejecutó antes del `DROP COLUMN`.
- **`CREATE INDEX CONCURRENTLY cannot run inside a transaction block`:** lo
  lanzaste después de un `BEGIN`. Escribe `ROLLBACK;` y ejecútalo suelto.
- **Quedan restos:** `\d pedidos` te enseña columnas, triggers o índices
  `INVALID` que sobran.
