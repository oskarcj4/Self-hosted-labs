#!/usr/bin/env bash
# Lab 50 (Día 27): el token del uploader va como variable de entorno escrita en compose.yaml.
set -e
P=/home/analista/files
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t files/app:1.0 ./app >/dev/null
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 50 plantado."
