# Resolución guiada · Lab 157

:::piensa Primero añadir, luego quitar
Durante un despliegue conviven instancias viejas y nuevas de la app. Si
renombras la columna de golpe, las viejas buscan `nombre` y ya no existe:
errores. El patrón *expand / contract* evita ese instante: primero **añades**
lo nuevo (las dos columnas conviven), despliegas la app nueva, y sólo cuando
nadie usa lo viejo lo **quitas**.
:::

**El plan:** (1) ver el estado, (2) la revisión *expand*, (3) aplicarla y
mover la app, (4) la revisión *contract* y (5) aplicarla.

## Paso 1 · ¿Dónde estás?

:::pista Cómo hacerlo
```bash
cd /opt/shop
alembic history
alembic current
sqlite3 db.sqlite 'PRAGMA table_info(clientes);'
ls migrations/versions/
```
**Alembic** guarda los cambios de esquema como **revisiones**: ficheros
Python con una función `upgrade()` (aplicar) y `downgrade()` (deshacer),
encadenados por `down_revision` (la revisión anterior).
- `history`: la cadena de revisiones. `current`: en cuál está la base.
- `PRAGMA table_info` lista las columnas de una tabla en SQLite.

**Qué deberías ver:** una sola revisión (`0001`, la de partida) y la columna
`nombre`.
:::

## Paso 2 · *Expand*: la columna nueva

:::pista Cómo hacerlo
Crea `migrations/versions/0002_expand.py`:
```python
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("clientes", sa.Column("nombre_completo", sa.String(100)))
    op.execute("UPDATE clientes SET nombre_completo = nombre")

def downgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre_completo")
```
- `revision` y `down_revision` encadenan esta revisión detrás de la `0001`.
- `add_column` añade la columna; el `UPDATE` copia los datos existentes.
- `downgrade` deshace el paso, por si hay que volver atrás.

(También puedes generar el esqueleto con `alembic revision -m "expand"`:
crea un fichero con un identificador aleatorio y el `down_revision` ya puesto;
sólo rellenas las funciones.)
:::

## Paso 3 · Aplícalo y mueve la app

:::pista Cómo hacerlo
```bash
alembic upgrade 0002
sqlite3 db.sqlite 'PRAGMA table_info(clientes);'
```
`upgrade 0002` aplica hasta esa revisión y se para.

**Qué deberías ver:** `nombre` y `nombre_completo` a la vez. Es el momento de
desplegar la app nueva. En `app.py`, cambia la consulta:
```python
for row in db.execute("SELECT id, nombre_completo FROM clientes"):
```
```bash
python3 app.py
```
En producción, aquí desplegarías y esperarías a que no quede ninguna
instancia vieja.
:::

## Paso 4 · *Contract*: quitar lo viejo

:::pista Cómo hacerlo
Crea `migrations/versions/0003_contract.py`:
```python
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

def upgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre")

def downgrade():
    op.add_column("clientes", sa.Column("nombre", sa.String(100)))
    op.execute("UPDATE clientes SET nombre = nombre_completo")
```
SQLite no sabe borrar columnas con un simple `ALTER TABLE` (en versiones
antiguas). `batch_alter_table` lo resuelve como lo haría a mano: crea una
tabla nueva sin la columna, copia los datos y sustituye la vieja.
:::

## Paso 5 · Aplícalo y comprueba

```bash
alembic upgrade head
alembic current
sqlite3 db.sqlite 'PRAGMA table_info(clientes);'
python3 app.py
bash /opt/lab/check.sh
```
`head` es la última revisión de la cadena.

**Qué deberías ver:** `0003 (head)`, sólo `nombre_completo`, con los datos, y
la app funcionando.

## Cómo actuar en una situación así

- El orden importa: expand → desplegar la app → contract. Nunca al revés.
- Cada fase en su propia revisión, con `downgrade` para poder volver atrás.
- En bases grandes, el `UPDATE` de copia se hace por lotes (lab 220).

## Si te atascas

- **`Multiple head revisions`:** dos revisiones tienen el mismo
  `down_revision`. Revisa la cadena con `alembic history`.
- **El `drop_column` falla:** falta el `batch_alter_table`.
- **El check pide 3 revisiones:** expand y contract van en ficheros separados.
