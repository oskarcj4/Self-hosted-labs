#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/portal
mkdir -p /home/analista/evidencia-INC-3107
cp compose.override.yaml /home/analista/evidencia-INC-3107/
rm compose.override.yaml
docker compose up -d --remove-orphans
sleep 2
