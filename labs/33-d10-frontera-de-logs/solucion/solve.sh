#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
chown payments:payments /var/log/payments
chmod 0750 /var/log/payments
chown payments:payments /var/log/payments/transactions.log*
chmod 0640 /var/log/payments/transactions.log*
sed -i 's/^\(\s*\)create .*/\1create 0640 payments payments/' /etc/logrotate.d/payments
