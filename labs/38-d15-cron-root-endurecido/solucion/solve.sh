#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
install -m 0755 -o root -g root /var/tmp/jobs/cleanup-cache.sh /usr/local/sbin/cleanup-cache
sed -i 's#/var/tmp/jobs/cleanup-cache.sh#/usr/local/sbin/cleanup-cache#' /etc/cron.d/cache-cleanup
chown root:root /etc/cron.d/cache-cleanup
chmod 0644 /etc/cron.d/cache-cleanup
rm -rf /var/tmp/jobs
