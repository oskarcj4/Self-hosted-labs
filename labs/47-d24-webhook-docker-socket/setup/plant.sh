#!/usr/bin/env bash
# Lab 47 (Día 24): un receptor de webhooks expuesto con el socket de Docker montado.
set -e
P=/home/analista/deployhook
mkdir -p "$P/events"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t deployhook/webhook:1.2 ./webhook >/dev/null
echo "2026-10-18T09:00:00 /hook {\"repo\":\"shop\",\"ref\":\"main\"}" > events/events.log
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 47 plantado."
