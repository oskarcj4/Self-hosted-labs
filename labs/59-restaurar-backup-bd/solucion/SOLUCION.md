# Solución — Restaurar tras un borrado accidental

## 1. ¿Qué backup sirve?

```bash
ls -l /var/backups/pg/
# 0 bytes  tienda-2026-10-20.dump    <- el de hoy está VACÍO
# ~60 KB   tienda-2026-10-19.dump
cat /var/log/pg-backup.log          # el de hoy falló (pg_dump exit 1)
sudo -u postgres pg_restore -l /var/backups/pg/tienda-2026-10-19.dump | grep -i pedidos
```

Un backup que nadie ha restaurado nunca es una hipótesis. Aquí el job de hoy
"terminó" y dejó un fichero vacío. Nadie se enteró porque nadie miraba ni el
log ni el tamaño.

## 2. Restaurar en una base de datos aparte

```bash
sudo -u postgres createdb tienda_restore
sudo -u postgres pg_restore -d tienda_restore /var/backups/pg/tienda-2026-10-19.dump
sudo -u postgres psql -d tienda_restore -c 'select count(*) from pedidos'   # 2000
```

**No** hagas `pg_restore --clean -d tienda ...`: borraría y recrearía
`clientes` con los 500 de anoche, y perderías los 5 de hoy.

## 3. Llevar sólo `pedidos` a producción

`pg_dump -t pedidos` saca la tabla **con** su estructura: PK, FK, índice, la
secuencia del `serial` y el `OWNER TO tienda`.

```bash
sudo -u postgres pg_dump -t pedidos -t pedidos_id_seq tienda_restore > /tmp/pedidos.sql
grep -E 'CREATE|ALTER|OWNER' /tmp/pedidos.sql      # revisa antes de aplicar
sudo -u postgres psql -d tienda -v ON_ERROR_STOP=1 -1 -f /tmp/pedidos.sql
```

Con `-1`, todo se aplica en una sola transacción: o entra entero, o no entra
nada.

> ¿Por qué no `pg_restore -t pedidos -d tienda`? Con `-t`, `pg_restore`
> restaura **sólo** la tabla y sus datos, sin índices, sin restricciones y sin
> la secuencia. La app parece funcionar, pero el siguiente `INSERT` falla.

## 4. Verificar y limpiar

```bash
sudo -u postgres psql -d tienda -c '\d pedidos'     # PK, FK, índice, default nextval
sudo -u postgres psql -d tienda -tAc 'select count(*) from clientes'   # 505
curl -s http://127.0.0.1:8080/health
sudo -u postgres dropdb tienda_restore
```

## 5. Lo que va al postmortem

- Se perdieron los **pedidos de hoy** (desde las 02:00 hasta las 11:42): no
  estaban en ningún backup. Con un dump diario, eso es lo máximo que puedes
  perder (tu RPO). Para perder menos hace falta archivado de WAL /
  *point-in-time recovery*.
- El backup de hoy falló y nadie se enteró. Alerta si el job sale con error o
  si el fichero pesa mucho menos que el de ayer.
- Ensaya la restauración cada cierto tiempo. Un backup no vale nada hasta que
  lo has restaurado.

## Lecciones

- Restaura **al lado** (otra base de datos) y lleva sólo lo que falta.
- `pg_dump -t tabla` lleva la estructura completa de esa tabla;
  `pg_restore -t tabla` no.
- Comprueba el backup antes de usarlo: tamaño, log y `pg_restore -l`.
