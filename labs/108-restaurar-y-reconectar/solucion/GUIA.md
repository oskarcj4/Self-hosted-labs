# Resolución guiada · Restaurar un backup y reconectar la app

:::piensa Antes de tocar nada
Dos problemas encadenados, y el orden importa: la base de producción se perdió
**y** durante el pánico apuntaron la app a un failover que no existe. Restaurar
la base no arregla la app por sí solo; reconfigurar la app no sirve si la base
no está. Y no todos los backups valen: el de esta madrugada falló. Primero
elige un backup bueno, restaura, y luego reconecta la app.
:::

## Paso 1 · Confirma el daño

**Pregúntate:** ¿qué dice exactamente el error de la app?

:::pista Cómo verlo
```bash
curl -s http://127.0.0.1:8080/health | jq       # detalle: database "tienda_dr" does not exist
sudo -u postgres psql -l | grep tienda           # la base 'tienda' no aparece
```
La base no existe y el DSN apunta a `tienda_dr`: dos cosas que arreglar.
:::

## Paso 2 · Elige el backup bueno

**Pregúntate:** ¿el backup más reciente sirve, o solo existe?

:::pista Cómo comprobarlo
```bash
ls -l /var/backups/tienda/              # el de hoy (19) pesa 0 bytes
cat /var/backups/tienda/pg-backup.log   # confirma que el 19 falló
sudo -u postgres pg_restore -l /var/backups/tienda/tienda-2026-10-18.dump | head
```
Un backup que no puedes listar con `pg_restore -l` no es un backup.
:::

## Paso 3 · Restaura

**Pregúntate:** ¿hace falta recrear el rol? No: solo se borró la base; el ROLE
`tienda` sigue.

:::pista Cómo hacerlo
```bash
sudo -u postgres createdb -O tienda tienda
sudo -u postgres pg_restore -d tienda /var/backups/tienda/tienda-2026-10-18.dump
sudo -u postgres psql -d tienda -c 'SELECT count(*) FROM productos'   # 240
```
:::

## Paso 4 · Reconecta la app

**Pregúntate:** ¿por qué sigue en 503 si la base ya está? Porque apunta a otro
sitio y arrastra conexiones muertas.

:::pista Cómo hacerlo
```bash
cat /etc/tienda/db.conf        # port=5433 dbname=tienda_dr  <- mal
cat > /etc/tienda/db.conf <<'EOF'
host=127.0.0.1 port=5432 dbname=tienda user=tienda password=tienda
EOF
sudo systemctl restart tienda-web
curl -s http://127.0.0.1:8080/health | jq     # {"status":"ok","productos":240}
```
Corrige el DSN **y reinicia** el servicio para que abra conexiones nuevas.
:::

## Paso 5 · Verifica

```bash
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Orden**: restaura la base primero, reconecta la app después.
- **Valida el backup antes de usarlo**: `pg_restore -l`, tamaño y log; el más
  reciente puede estar roto.
- **ROLE ≠ base de datos**: puedes perder una y conservar el otro.
- **Restaurar y reconectar son dos pasos**: base + configuración + reinicio.
- **Postmortem**: RPO (lo perdido desde el último backup bueno), alerta de
  backups fallidos, y ensayar la restauración periódicamente.

## Si te atascas

- `pg_restore` se queja del OWNER → el ROLE `tienda` no existe; créalo
  (`CREATE ROLE tienda LOGIN PASSWORD 'tienda';`) y repite.
- Restauraste pero `/health` sigue 503 → es el paso 4: db.conf apunta a
  `tienda_dr`/5433, o no reiniciaste `tienda-web`.
- `createdb: already exists` → ya la creaste; restaura directamente, o bórrala y
  recréala si quedó a medias.
