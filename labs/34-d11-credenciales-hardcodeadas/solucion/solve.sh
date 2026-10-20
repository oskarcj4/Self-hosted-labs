#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
install -d -m 0700 -o root -g root /etc/maint
install -m 0600 -o root -g root /dev/null /etc/maint/db.cred
printf "DB_USER=maint\nDB_PASSWORD='Vk7#pR2-maint-2026'\n" > /etc/maint/db.cred
sed -i -e '/^DB_USER=/d' -e "/^DB_PASSWORD=/c\\
# Credenciales fuera del código (root, 0600)\\
. /etc/maint/db.cred || { echo 'ERROR: no puedo leer /etc/maint/db.cred'; exit 1; }" \
  /opt/maint/db-maintenance.sh
chown root:root /opt/maint/db-maintenance.sh
chmod 0755 /opt/maint/db-maintenance.sh
rm -f /opt/maint/db-maintenance.sh.orig
