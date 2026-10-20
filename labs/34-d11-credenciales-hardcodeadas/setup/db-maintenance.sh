#!/bin/bash
# Mantenimiento nocturno de la BD de pedidos.
# Lo lanza cron como root: /etc/cron.d/db-maint
DB_HOST=127.0.0.1
DB_PORT=5433
DB_USER=maint
DB_PASSWORD='Vk7#pR2-maint-2026'

exec 3<>"/dev/tcp/$DB_HOST/$DB_PORT" || { echo "ERROR: no conecto con $DB_HOST:$DB_PORT"; exit 1; }
printf 'AUTH %s %s\nVACUUM\nQUIT\n' "$DB_USER" "$DB_PASSWORD" >&3
read -r auth <&3
read -r vac <&3
exec 3>&-

if [ "$auth" = "OK auth" ] && [ "$vac" = "OK vacuum done" ]; then
  echo "$(date '+%F %T') VACUUM OK"
else
  echo "$(date '+%F %T') ERROR: $auth / $vac"
  exit 1
fi
