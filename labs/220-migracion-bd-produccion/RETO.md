# Migración de PostgreSQL en plena producción

> DevOps · PostgreSQL 15 · expand/contract · backfill por lotes · `CONCURRENTLY` · `lock_timeout` · zero downtime

## Escenario

La tabla `pedidos` de la tienda tiene **3 millones de filas** y su clave
`id` es `integer`. La secuencia ya va por **2 146 millones**, y el máximo es
2 147 483 647. En unas horas **todos los INSERT fallarán**.

Hay que pasar `id` a `bigint`, pero la tienda no se puede cerrar. Ahora mismo
hay **tráfico real** contra la base: pedidos nuevos, lecturas y cambios de
estado, cientos por segundo.

La app usa `lock_timeout = 1s`. Si una operación espera un bloqueo más de
1 s, falla y el cliente ve un error.

| Servicio | URL |
|----------|-----|
| Panel de tráfico en vivo | <http://localhost:8220> |

## Objetivos

1. `pedidos.id` es `bigint`, es la clave primaria y toma su valor de una secuencia `bigint`.
2. Los ids existentes **no cambian** y no se pierde **ningún** pedido confirmado.
3. **0 errores** de tráfico durante la migración.
4. El tráfico **no se para** en ningún momento.
5. No quedan restos: ni columnas auxiliares, ni triggers, ni índices inválidos.

Si un intento sale mal: `sudo reiniciar-tienda` restaura la base y pone el
contador de errores a cero.

## Pistas

```bash
cat ~/TAREA.txt; trafico 30
psql tienda -c '\d pedidos'
```

¿Qué bloqueo toma `ALTER COLUMN ... TYPE`? ¿Y un `UPDATE` de 3 M filas de una
vez? ¿Y `CREATE INDEX` sin `CONCURRENTLY`? Busca el patrón
**expand / contract**: una columna nueva, un trigger, un backfill por lotes,
`ADD PRIMARY KEY USING INDEX` y un cambio final muy corto.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
