#!/usr/bin/env bash
set -e
P=/home/analista/caps
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
chown -R analista:analista "$P"
cd "$P"
docker compose up -d --build
echo "Lab 89 plantado."
