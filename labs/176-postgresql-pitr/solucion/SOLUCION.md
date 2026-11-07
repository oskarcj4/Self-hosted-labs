# Solución — PostgreSQL PITR

## Línea de tiempo

```
anoche      pg_basebackup  ->  /var/backups/pg/base    (120 pedidos)
mañana      +40 pedidos    (sólo en el WAL archivado)
T           DELETE FROM pedidos;                       <- en el log
T+3 s       +8 pedidos "despues-*"
```

Objetivo: `recovery_target_time = T − 1 s`.

## Pasos

1. `grep 'DELETE FROM pedidos' /var/log/postgresql/postgresql-15-main.log` → T.
2. Copia del backup en `/var/lib/postgresql/restaurada`, con:
   - `postgresql.conf`: `port = 5433`, `hba_file`, `restore_command = 'cp /var/lib/pg-archivo/%f %p'`,
     `recovery_target_time`, `recovery_target_action = 'promote'`, `archive_mode = off`;
   - `recovery.signal`;
   - `pg_ctl -D ... start` como postgres.
3. `\copy pedidos TO` desde 5433 → tabla temporal en 5432 →
   `INSERT ... WHERE NOT EXISTS (mismo id)`.

Resultado en producción: 160 + 8 = 168 pedidos, todos los importes cuadran.

## Por qué

- El backup base sin WAL sólo vuelve a "anoche". El WAL lleva cada cambio con
  su hora, así que se puede parar en cualquier punto.
- `recovery_target_action = 'promote'` deja la copia abierta para leer y
  escribir; con `pause` podrías inspeccionar y avanzar poco a poco.

## Más allá del lab

- pgBackRest o WAL-G: backups y archivo en S3, con verificación y retención.
- Métrica de "edad del último WAL archivado": si no avanza, no hay PITR.
- `recovery_target_xid` o `recovery_target_lsn` cuando hace falta más precisión que el segundo.
