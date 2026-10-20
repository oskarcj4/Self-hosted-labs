#!/usr/bin/env bash
# Lab 43 (Día 20): la base de datos quedó publicada en el host desde una migración.
set -e
P=/home/analista/inventory
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t inventory/app:2.0 ./app >/dev/null
docker compose up -d
chown -R analista:analista "$P"
echo "Lab 43 plantado."
