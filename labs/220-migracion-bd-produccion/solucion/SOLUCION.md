# Solución — Migración de PostgreSQL en plena producción

| Qué rompe el tráfico | Alternativa sin downtime |
|----------------------|--------------------------|
| `ALTER COLUMN id TYPE bigint` (reescribe la tabla con `ACCESS EXCLUSIVE`) | columna `id_nuevo bigint` + trigger + swap final |
| `UPDATE` de 3 M filas de golpe (bloquea todas las filas hasta el `COMMIT`) | backfill en lotes de 5 000 con pausa |
| `CREATE INDEX` (bloquea escrituras) | `CREATE UNIQUE INDEX CONCURRENTLY` |
| `SET NOT NULL` directo (escanea con `ACCESS EXCLUSIVE`) | `CHECK ... NOT VALID` + `VALIDATE CONSTRAINT`, luego `SET NOT NULL` |
| Crear la PK de cero (construye el índice bloqueando) | `ADD PRIMARY KEY USING INDEX` sobre el índice ya hecho |
| DDL esperando un bloqueo con la app haciendo cola detrás | `lock_timeout` corto en la sesión de migración, y reintentar |

Todo automatizado en `solve.sh` (unos 2–3 minutos con tráfico).

## Notas

- **Expand / contract** sirve para cualquier cambio de esquema incompatible:
  renombrar columnas, partir una columna en dos, cambiar tipos. Primero la app
  y la base aceptan **las dos** formas. Después se migran los datos. Por último
  se elimina la vieja.
- **Claves foráneas**: si otras tablas apuntan a `pedidos.id`, sus columnas
  también deben pasar a `bigint` con el mismo método. Luego se recrean las FK
  con `NOT VALID` + `VALIDATE`.
- **`synchronous_commit = off`** solo en la sesión del backfill: si el
  servidor cae, como mucho se pierden los últimos lotes, y el script los
  repite (`WHERE id_nuevo IS NULL`). No lo uses en la sesión de la app.
- **Herramientas**: `pg-osc`, `pgroll` o `reshape` automatizan este patrón.
  Saber hacerlo a mano ayuda a entender qué hacen y cuándo fallan.
- **Prevención**: crea las claves como `bigint` (o `identity` bigint) desde el
  principio. Un `bigint` vacío ocupa 4 bytes más por fila, y migrar después
  cuesta mucho más.
