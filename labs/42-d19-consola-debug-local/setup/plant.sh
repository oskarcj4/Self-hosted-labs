#!/usr/bin/env bash
# Lab 42 (Día 19): consola de depuración (eval sin autenticación) publicada
# en todas las interfaces del host.
set -e
P=/home/analista/billing
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t billing/api:1.4 ./app >/dev/null
docker compose up -d
chown -R analista:analista "$P"
echo "Lab 42 plantado."
