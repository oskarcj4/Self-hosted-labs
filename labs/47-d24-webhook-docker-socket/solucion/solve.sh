#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/deployhook
sed -i '/docker.sock/d' compose.yaml
docker compose up -d
sleep 2
