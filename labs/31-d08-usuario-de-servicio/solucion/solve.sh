#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
useradd --system --no-create-home --home-dir /var/lib/reportd --shell /usr/sbin/nologin reportd
chown -R reportd:reportd /var/lib/reportd /var/log/reportd
chown root:reportd /etc/reportd/reportd.conf
chmod 0640 /etc/reportd/reportd.conf
mkdir -p /etc/systemd/system/reportd.service.d
printf '[Service]\nUser=reportd\nGroup=reportd\n' > /etc/systemd/system/reportd.service.d/user.conf
systemctl daemon-reload
systemctl restart reportd
sleep 7
