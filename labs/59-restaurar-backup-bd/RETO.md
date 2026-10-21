# Restaurar tras un borrado accidental

> Operaciones · PostgreSQL · backups · incidente P1 (catastrófico)

## Escenario

A las 11:42 un script de limpieza se lanzó contra producción y ejecutó
`DROP TABLE pedidos;`. La web de la tienda da 500. Lee
`~/ticket/INC-5002.txt`.

Tienes backups en `/var/backups/pg/`. Pero, desde el backup de anoche, se han
dado de alta **5 clientes nuevos** que no están en ningún backup. Si
restauras la base de datos entera encima, los pierdes.

## Objetivos

1. Elige el backup **bueno**. No todos los ficheros de backup sirven.
2. Recupera la tabla `pedidos` completa: datos, clave primaria, clave
   foránea, índice y secuencia, con su dueño original (`tienda`).
3. **No pierdas** los 505 clientes actuales.
4. `tienda-web /health` responde 200.

> Truco de los que han pasado por esto: no restaures directamente sobre
> producción. Restaura en una base de datos aparte, compara y lleva sólo lo
> que falta.

## Comandos que te pueden servir

```bash
ls -l /var/backups/pg/ ; cat /var/log/pg-backup.log
sudo -u postgres pg_restore -l /var/backups/pg/FICHERO.dump | less   # índice del backup
sudo -u postgres createdb tienda_restore
sudo -u postgres pg_restore -d tienda_restore /var/backups/pg/FICHERO.dump
sudo -u postgres pg_dump -t pedidos tienda_restore | less
sudo -u postgres psql -d tienda -c '\d pedidos'
curl -s http://127.0.0.1:8080/health
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
