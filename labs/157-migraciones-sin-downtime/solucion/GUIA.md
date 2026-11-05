# Resolución guiada · Lab 157

:::piensa Un paso aditivo, luego limpieza
Nunca cambies el esquema de golpe mientras hay despliegue. Añade lo nuevo,
despliega, y solo después borra lo viejo. Cada paso compatible hacia atrás.
:::

## Paso 1 · Expand

:::pista Cómo hacerlo
```python
# migrations/versions/0002_expand.py  (down_revision = "0001")
def upgrade():
    op.add_column("clientes", sa.Column("nombre_completo", sa.String(100)))
    op.execute("UPDATE clientes SET nombre_completo = nombre")
```
Las dos columnas conviven: nadie se rompe.
:::

## Paso 2 · Contract

:::pista Cómo hacerlo
```python
# migrations/versions/0003_contract.py  (down_revision = "0002")
def upgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre")
```
En SQLite, `drop_column` necesita `batch_alter_table` (reescribe la tabla).
:::

## Paso 3 · Aplicar y mover la app

:::pista Cómo hacerlo
```bash
cd /opt/shop && alembic upgrade head
# app.py -> SELECT id, nombre_completo FROM clientes
```
:::

## Cómo actuar en una situación así

- El orden importa: expand → desplegar app → contract. Nunca al revés.
- Mantén la revisión reversible (`downgrade`) por si hay que volver atrás.

## Si te atascas

- `alembic upgrade` falla en el drop: te falta `batch_alter_table` (SQLite).
- El check dice "falta contract": dejaste `nombre`; aplica la revisión 0003.
- "3 revisiones": cada fase va en SU fichero, no juntes expand y contract.
