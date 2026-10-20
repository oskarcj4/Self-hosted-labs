#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
chown root:root /etc/notifier/notifier.env
chmod 0600 /etc/notifier/notifier.env
rm -f /etc/notifier/notifier.env.bak
systemctl restart notifier
sleep 1
