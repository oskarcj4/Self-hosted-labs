# Restaurar un backup y reconectar la app

> Operaciones · PostgreSQL · backups · pg_restore · incidente P1

## Escenario

La tienda (`tienda-01`) está caída. La API `tienda-web` devuelve 503 y, según
el guardia, "alguien borró la base de datos de producción". En el pánico,
además, tocaron la configuración de la app.

```bash
cat ~/PISTA.txt
curl -s http://127.0.0.1:8080/health | jq
```

Tienes backups en `/var/backups/tienda/`. **No todos sirven**: el de esta
madrugada falló. La app lee su conexión de `/etc/tienda/db.conf`.

## Objetivos

1. Restaura la base `tienda` desde el backup **bueno** (240 productos, 1200
   pedidos).
2. Reconecta la app: `tienda-web` vuelve a hablar con la base restaurada.
3. `curl http://127.0.0.1:8080/health` responde `{"status":"ok","productos":240}`.

## Comandos que te pueden servir

```bash
ls -l /var/backups/tienda/ ; cat /var/backups/tienda/pg-backup.log
sudo -u postgres pg_restore -l /var/backups/tienda/FICHERO.dump | head   # ¿es válido?
sudo -u postgres psql -l                                                 # ¿existe 'tienda'?
sudo -u postgres createdb -O tienda tienda
sudo -u postgres pg_restore -d tienda /var/backups/tienda/FICHERO.dump
cat /etc/tienda/db.conf                                                   # ¿adónde apunta la app?
sudo systemctl restart tienda-web ; sudo journalctl -u tienda-web -n 20 --no-pager
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
