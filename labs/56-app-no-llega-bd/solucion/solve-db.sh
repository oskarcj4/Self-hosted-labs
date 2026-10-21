#!/usr/bin/env bash
# Solución automática, parte db-01 (sirve para probar el lab). Corre como root en db-01.
set -e
sed -i 's#10\.76\.56\.99/32#10.76.56.10/32#' /etc/iptables/rules.v4
iptables-restore /etc/iptables/rules.v4
sed -i 's/^listen_address = 127.0.0.1/listen_address = 10.76.56.20/' /etc/minidb/minidb.conf
systemctl restart minidb
sleep 1
