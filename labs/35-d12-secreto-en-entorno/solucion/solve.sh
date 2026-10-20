#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
install -d -m 0750 -o root -g ingest /etc/ingest
install -m 0640 -o root -g ingest /dev/null /etc/ingest/api_token
echo 'ing_live_4f7a9c2e8b1d6f3a5c0e' > /etc/ingest/api_token
sed -i 's#^Environment=INGEST_API_TOKEN=.*#Environment=INGEST_TOKEN_FILE=/etc/ingest/api_token#' \
  /etc/systemd/system/ingest.service
systemctl daemon-reload
systemctl restart ingest
sleep 1
