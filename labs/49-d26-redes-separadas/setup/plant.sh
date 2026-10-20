#!/usr/bin/env bash
# Lab 49 (Día 26): tres capas en una única red plana: web llega directo a db.
set -e
P=/home/analista/store
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t store/app:1.0 ./app >/dev/null
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 49 plantado."
