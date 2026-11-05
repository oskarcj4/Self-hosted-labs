# Solución — Migraciones sin downtime

## Las dos revisiones

**Expand** (`0002_expand.py`): añade la columna nueva y copia los datos. Las dos
columnas conviven, así que la app vieja (`nombre`) y la nueva (`nombre_completo`)
funcionan a la vez.

```python
def upgrade():
    op.add_column("clientes", sa.Column("nombre_completo", sa.String(100)))
    op.execute("UPDATE clientes SET nombre_completo = nombre")
```

**Contract** (`0003_contract.py`): cuando ya nadie usa `nombre`, se elimina. En
SQLite hace falta `batch_alter_table` (reescribe la tabla).

```python
def upgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre")
```

Luego `alembic upgrade head` y la app nueva lee `nombre_completo`.

## Por qué expand/contract

El despliegue no es atómico: durante unos segundos conviven versiones vieja y
nueva de la app. Si la base de datos cambia de golpe, una de las dos rompe. Con
expand/contract, **cada paso del esquema es compatible con la app que está
corriendo**:

| Momento | Esquema | App vieja | App nueva |
|---------|---------|-----------|-----------|
| Antes | `nombre` | ✅ | — |
| Tras expand | `nombre` + `nombre_completo` | ✅ | ✅ |
| Tras desplegar | ídem | (retirada) | ✅ |
| Tras contract | `nombre_completo` | — | ✅ |

## Más allá del lab

- Mismo patrón para dividir/unir columnas, cambiar tipos o mover datos entre
  tablas: siempre un paso aditivo, despliegue, y un paso de limpieza.
- Backfills grandes: hazlos por lotes para no bloquear la tabla.
- En PostgreSQL, cuida los locks: `ADD COLUMN` con default no volátil es barato
  en versiones modernas; evita reescrituras de tabla en horas punta.
