#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
stat -c '%a %U %n' /home/deploy/.ssh /home/deploy/.ssh/* /srv/app/.env
find / -xdev -type f -perm -0002 2>/dev/null
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/id_ed25519 /home/deploy/.ssh/authorized_keys
chmod 600 /srv/app/.env
chmod 755 /usr/local/bin/backup.sh
chmod 644 /etc/app/config.yml
find / -xdev -type f -perm -0002 -not -path '/proc/*' -not -path '/sys/*' -exec chmod o-w {} + 2>/dev/null || true
rm -f /etc/profile.d/99-umask-compat.sh
sed -i 's/^umask 000.*/umask 027/' /home/deploy/.profile
