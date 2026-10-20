#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
sed -i '1a\
# No confiar en el PATH heredado (cron, sudo, otro script...)\
PATH=/usr/sbin:/usr/bin:/sbin:/bin\
export PATH' /usr/local/sbin/backup-config.sh
chown root:root /usr/local/sbin/backup-config.sh
chmod 0755 /usr/local/sbin/backup-config.sh
chown -R root:root /opt/tools
chmod 0755 /opt/tools /opt/tools/bin /opt/tools/bin/s3sync
sed -i 's#^PATH=.*#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#' /etc/cron.d/backup-config
