#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/billing
sed -i 's#- "5555:5555"#- "127.0.0.1:5555:5555"#' compose.yaml
docker compose up -d
sleep 2
