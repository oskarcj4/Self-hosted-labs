# Resolución guiada · Lab 191

:::piensa ¿Qué versiones del código van a ver este esquema?
Durante el despliegue y tras un rollback, la v1 y la v2 usan **la misma**
base de datos, a veces a la vez. El esquema tiene que servir a las dos. Por
eso una migración no puede romper la versión anterior.
:::

## Paso 1 · Expandir en lugar de renombrar

:::pista Cómo hacerlo
```sql
ALTER TABLE clientes ADD COLUMN nombre_completo TEXT;
UPDATE clientes SET nombre_completo = nombre WHERE nombre_completo IS NULL;
```
La columna `nombre` se queda.
:::

## Paso 2 · Escribir en las dos

:::pista Cómo hacerlo
La v2 hace `INSERT ... (nombre, nombre_completo) VALUES (?, ?)`. Así, tras
un rollback, la v1 ve el nombre de los clientes creados con v2.
:::

## Paso 3 · Lo que escribe la v1 después del rollback

:::pista Cómo hacerlo
La v1 sólo rellena `nombre`. Al volver a v2, esos clientes tendrían
`nombre_completo` vacío. Dos defensas: leer con
`COALESCE(nombre_completo, nombre)` y un trigger `AFTER INSERT` que copie
`nombre` cuando `nombre_completo` llega vacío.
:::

## Paso 4 · Ensaya el rollback

:::pista Qué hacer
Haz una copia de la base de datos y luego `desplegar v2`, `desplegar v1` y
`desplegar v2`, creando un cliente en cada paso. Al terminar, restaura la copia.
:::

## Cómo actuar en una situación así

- Revisión de migraciones en el PR: `RENAME`, `DROP` y `NOT NULL` sin valor por defecto son señales de alarma.
- El contraer es otra release, con fecha, cuando ya no se puede volver a la versión anterior.
- Si ya rompiste producción con un rename: lo más rápido suele ser desplegar hacia delante (v2 arreglada), no hacia atrás.
