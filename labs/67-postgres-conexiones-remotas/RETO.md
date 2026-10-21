# PostgreSQL rechaza las conexiones remotas

> Operaciones · PostgreSQL · listen_addresses · pg_hba.conf · SSH

## Escenario

Desde el martes, `informe-diario.sh` (en `app-04`) no puede conectar con
PostgreSQL en `pg-01`. Ese mismo día seguridad aplicó un hardening en `pg-01`.
Lee `~/ticket/INC-6707.txt`: ahí tienes el acceso a `pg-01` y los requisitos
de seguridad de la excepción.

## Objetivos

1. PostgreSQL escucha en `localhost` **y** en la IP interna de `pg-01`
   (10.76.67.20). **No** en `'*'`.
2. Sólo `app-04` (10.76.67.10), sólo el usuario `informes`, sólo la BD
   `ventas`, con `scram-sha-256`.
3. El resto de la red sigue rechazado: la regla `reject` se queda.
4. `informe-diario.sh` funciona desde `app-04`.

## Comandos que te pueden servir

```bash
# en app-04
/usr/local/bin/informe-diario.sh
psql "host=pg-01 dbname=ventas user=informes" -c 'select 1'
ssh dba@pg-01

# en pg-01
sudo ss -ltnp | grep 5432
sudo -u postgres psql -c 'SHOW listen_addresses'
sudo -u postgres psql -c "SELECT name, setting, sourcefile FROM pg_settings WHERE name='listen_addresses'"
sudo -u postgres psql -c 'SELECT line_number, type, database, user_name, address, auth_method FROM pg_hba_file_rules'
sudo ls /etc/postgresql/15/main/ /etc/postgresql/15/main/conf.d/
sudo tail -n 20 /var/log/postgresql/postgresql-15-main.log
sudo systemctl reload postgresql     # basta para pg_hba.conf
sudo systemctl restart postgresql    # necesario para listen_addresses
```

## Cuando creas que terminaste

Desde `app-04`:

```bash
bash /opt/lab/check.sh
```
