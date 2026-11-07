# Solución — Rollback con cambio de base de datos

## Migración 002 (expandir)

```sql
ALTER TABLE clientes ADD COLUMN nombre_completo TEXT;
UPDATE clientes SET nombre_completo = nombre WHERE nombre_completo IS NULL;
CREATE TRIGGER clientes_sincroniza_nombre AFTER INSERT ON clientes
WHEN NEW.nombre_completo IS NULL
BEGIN
  UPDATE clientes SET nombre_completo = NEW.nombre WHERE id = NEW.id;
END;
```

## v2

```python
c.execute("SELECT id, COALESCE(nombre_completo, nombre) FROM clientes ORDER BY id")
c.execute("INSERT INTO clientes (nombre, nombre_completo) VALUES (?, ?)", (nombre, nombre))
```

## Las tres fases

| Release | Esquema | Código |
|---------|---------|--------|
| v2 (expandir) | `nombre` + `nombre_completo` + trigger | lee la nueva, escribe las dos |
| v3 | igual | sólo usa `nombre_completo`. El rollback a v2 sigue siendo seguro. |
| v4 (contraer) | `DROP TRIGGER`, `DROP COLUMN nombre` | — (ya nadie puede volver a v1) |

## Por qué no "down migrations"

Una migración hacia atrás de un rename funciona en un esquema vacío. En
producción, entre la ida y la vuelta se escribieron datos con la forma
nueva, y la vuelta los pierde o falla. Cada release tiene que ser
compatible con la anterior.

## Más allá del lab

- Lab 157: la misma idea con Alembic y PostgreSQL, sin downtime.
- En tablas grandes, rellena por lotes, no con un `UPDATE` de toda la tabla de golpe.
- Herramientas que avisan: `squawk` (PostgreSQL), `strong_migrations` (Rails).
