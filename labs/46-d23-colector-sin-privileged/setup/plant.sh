#!/usr/bin/env bash
# Lab 46 (Día 23): un colector de logs corre con privileged: true.
set -e
P=/home/analista/logs
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t logs/collector:0.9 ./collector >/dev/null
mkdir -p logs out
{
  for i in $(seq 1 20); do echo "2026-10-19T10:$((10+i)):00 app INFO petición $i"; done
  echo "2026-10-19T10:40:00 app WARN latencia alta"
  echo "2026-10-19T10:41:00 app ERROR timeout con pagos"
} > logs/app.log
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 46 plantado."
