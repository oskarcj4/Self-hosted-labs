#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
mkdir -p /etc/systemd/system/ingest.service.d
printf '[Service]\nLimitNOFILE=4096\n' > /etc/systemd/system/ingest.service.d/override.conf
systemctl daemon-reload
systemctl reset-failed ingest
systemctl restart ingest
sleep 2
