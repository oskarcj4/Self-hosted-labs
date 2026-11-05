# Migraciones sin downtime

> Imagen y ejecución · Alembic · expand/contract · esquema · despliegue

## Escenario

En `/opt/shop` hay un proyecto **Alembic** (SQLite en `/opt/shop/db.sqlite`). La
tabla `clientes` tiene la columna `nombre`. Negocio pide renombrarla a
`nombre_completo`.

Si la renombras de golpe (`ALTER TABLE ... RENAME COLUMN`) durante un despliegue,
hay un instante en que la base de datos ya cambió pero todavía corren instancias
viejas que buscan `nombre`: errores en producción. La solución es
**expand/contract**:

1. **Expand**: añades la columna nueva (`nombre_completo`), copias los datos.
   Las dos columnas conviven. La app vieja sigue con `nombre`; la nueva ya puede
   usar `nombre_completo`.
2. Despliegas la app nueva (lee/escribe `nombre_completo`).
3. **Contract**: cuando nadie usa `nombre`, la eliminas.

Cada paso es compatible hacia atrás: en ningún momento hay una versión de la app
que no cuadre con el esquema.

## Objetivos

1. Revisión **expand**: `op.add_column('nombre_completo')` + `UPDATE` que copie
   desde `nombre`.
2. Revisión **contract**: elimina `nombre` (en SQLite, con `batch_alter_table`).
3. `alembic upgrade head` y actualiza `app.py` para usar `nombre_completo`.

Estado final: `clientes` tiene `nombre_completo` (con los datos) y ya no tiene
`nombre`; 3 revisiones; `app.py` usa la columna nueva.

## Pistas

```bash
cd /opt/shop
alembic history          # ves 0001 (baseline)
alembic revision -m "expand: add nombre_completo"   # edita el fichero generado
alembic revision -m "contract: drop nombre"
alembic upgrade head
alembic current
sqlite3 db.sqlite 'PRAGMA table_info(clientes);'
```

Para eliminar columna en SQLite:
```python
with op.batch_alter_table("clientes") as b:
    b.drop_column("nombre")
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
