# Migración de datos en plena producción

> Operaciones · PostgreSQL · zero-downtime · locks · carga con k6

## Escenario

La tienda (`shop-01`) está **en producción y con tráfico real**. La tabla
`pedidos` guarda el importe en `total` como **céntimos** (un `integer`), y eso
arrastra bugs. Negocio pide migrar a una columna `total_eur` de tipo
`numeric(12,2)` en euros. No hay ventana de mantenimiento: hay que hacerlo **con
usuarios comprando**.

La tabla tiene 150.000 pedidos y crece: una migración ingenua toma un lock
`ACCESS EXCLUSIVE` sobre `pedidos`, y mientras dura, **hasta un `/health` se
cuelga**. Lo vas a ver tú mismo.

## Primero: pon el tráfico a correr

En **esta** pestaña:

```bash
cat ~/COMO-EMPEZAR.txt
k6 run /opt/lab/load.js        # 25 usuarios durante 90 s
```

Deja k6 corriendo y, en **otra** pestaña**, haz la migración. Mira cómo
`http_req_failed` y la latencia reaccionan a lo que hagas en la base de datos.

> Prueba, si quieres, la forma ingenua para *ver morir la tienda*:
> ```sql
> ALTER TABLE pedidos ALTER COLUMN total TYPE numeric(12,2) USING total/100.0;
> ```
> Toma `ACCESS EXCLUSIVE`, reescribe las 150k filas y bloquea lecturas y
> escrituras hasta terminar. k6 se llena de errores.

## Objetivos

1. Columna `total_eur` `numeric(12,2)`, **NOT NULL**.
2. Todas las filas con `total_eur = total/100` (backfill completo y correcto).
3. Los pedidos que entren **durante** la migración también quedan con
   `total_eur` (nada se pierde).
4. Hazlo **sin** un lock largo que tumbe el tráfico: idealmente k6 termina con
   `http_req_failed` por debajo del 1%.

## Comandos que te pueden servir

```bash
sudo -u postgres psql -d tienda
\d pedidos
-- ver quién bloquea a quién durante la migración:
SELECT pid, wait_event_type, state, left(query,60) FROM pg_stat_activity WHERE datname='tienda';
SELECT relation::regclass, mode, granted FROM pg_locks WHERE relation='pedidos'::regclass;
SET lock_timeout='3s';
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
