#!/usr/bin/env bash
# Lab 44 (Día 21): la configuración del gateway está montada en lectura/escritura.
set -e
P=/home/analista/edge
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t edge/gateway:3.1 ./gateway >/dev/null
sha256sum config/routes.conf | cut -d' ' -f1 > /root/.tclab-routes.sha
docker compose up -d
chown -R analista:analista "$P"
echo "Lab 44 plantado."
