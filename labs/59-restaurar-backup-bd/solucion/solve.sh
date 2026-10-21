#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
su postgres -c 'createdb tienda_restore'
su postgres -c 'pg_restore -d tienda_restore /var/backups/pg/tienda-2026-10-19.dump'
su postgres -c 'pg_dump -t pedidos -t pedidos_id_seq tienda_restore' > /tmp/pedidos.sql
su postgres -c 'psql -q -d tienda -v ON_ERROR_STOP=1 -1 -f /tmp/pedidos.sql'
su postgres -c 'dropdb tienda_restore'
