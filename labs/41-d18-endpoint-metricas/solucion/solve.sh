#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/shop
sed -i '/"9100:9100"/d' compose.yaml
docker compose up -d
sleep 2
