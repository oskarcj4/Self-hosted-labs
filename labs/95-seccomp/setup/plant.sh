#!/usr/bin/env bash
set -e
P=/home/analista/seccomp
mkdir -p "$P/profiles"
cp -r /opt/lab/setup/project/. "$P/"
cp /opt/seccomp/docker-default.json "$P/profiles/docker-default.json"
chmod 0755 "$P/probe.sh"
chown -R analista:analista "$P"
cd "$P"
docker compose up -d --build
echo "Lab 95 plantado."
