#!/usr/bin/env bash
set -e
P=/home/analista/edge
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
echo "edge-ok" > "$P/data/msg"
chown -R analista:analista "$P"
cd "$P"
docker compose up -d --build
echo "Lab 90 plantado."
