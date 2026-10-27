# Resolución guiada · Restaurar tras un borrado accidental

:::piensa Antes de tocar nada
`DROP TABLE pedidos` en producción. Hay backups, pero desde el de anoche
entraron **5 clientes nuevos** que no están en ninguno. Si restauras la base
entera encima, los pierdes. La regla de oro: **no restaures sobre producción**;
restaura al lado, compara y lleva sólo lo que falta.
:::

## Paso 1 · Elige el backup que de verdad sirve

**Pregúntate:** ¿el backup más reciente es válido, o sólo existe? Mira tamaño,
log y su índice.

:::pista Cómo comprobarlo
```bash
ls -l /var/backups/pg/            # el de hoy pesa 0 bytes -> inservible
cat /var/log/pg-backup.log        # el de hoy falló (pg_dump exit 1)
sudo -u postgres pg_restore -l /var/backups/pg/tienda-2026-10-19.dump | grep -i pedidos
```
Un backup que nadie restauró nunca es una hipótesis, no un backup.
:::

## Paso 2 · Restaura en una base aparte

**Pregúntate:** ¿cómo recupero `pedidos` sin tocar `clientes`? En otra base de
datos.

:::pista Cómo hacerlo
```bash
sudo -u postgres createdb tienda_restore
sudo -u postgres pg_restore -d tienda_restore /var/backups/pg/tienda-2026-10-19.dump
sudo -u postgres psql -d tienda_restore -c 'select count(*) from pedidos'   # 2000
```
**No** uses `pg_restore --clean -d tienda ...`: recrearía `clientes` con los de
anoche y perderías los 5 de hoy.
:::

## Paso 3 · Lleva SÓLO `pedidos` a producción

**Pregúntate:** ¿cómo llevo la tabla **completa** (datos, PK, FK, índice,
secuencia y dueño)? Con `pg_dump -t`, no con `pg_restore -t`.

:::pista Cómo hacerlo
```bash
sudo -u postgres pg_dump -t pedidos -t pedidos_id_seq tienda_restore > /tmp/pedidos.sql
grep -E 'CREATE|ALTER|OWNER' /tmp/pedidos.sql          # revísalo antes de aplicar
sudo -u postgres psql -d tienda -v ON_ERROR_STOP=1 -1 -f /tmp/pedidos.sql
```
`-1` lo aplica en una sola transacción: entra entero o no entra nada.

Por qué **no** `pg_restore -t pedidos -d tienda`: con `-t` restaura la tabla y
los datos pero **sin** índices, restricciones ni la secuencia; la app parece ir
y el siguiente `INSERT` revienta.
:::

## Paso 4 · Verifica y limpia

```bash
sudo -u postgres psql -d tienda -c '\d pedidos'            # PK, FK, índice, default nextval
sudo -u postgres psql -d tienda -tAc 'select count(*) from clientes'   # 505 (intactos)
curl -s http://127.0.0.1:8080/health
sudo -u postgres dropdb tienda_restore
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Restaura al lado**, compara y transfiere sólo lo que falta.
- **`pg_dump -t tabla`** lleva la estructura completa; `pg_restore -t` no.
- **Comprueba el backup antes de usarlo**: tamaño, log, `pg_restore -l`.
- **Postmortem**: los pedidos entre las 02:00 y las 11:42 se perdieron (ese es
  tu RPO con dump diario); para menos pérdida, archivado de WAL / PITR. Y
  alerta si el job falla o el fichero pesa mucho menos que el de ayer.

## Si te atascas

- El `\d pedidos` no muestra PK/secuencia → usaste `pg_restore -t`; rehazlo con
  `pg_dump -t` + `psql -f`.
- `clientes` bajó a 500 → restauraste sobre producción con `--clean`; vuelve al
  método de la base aparte.
