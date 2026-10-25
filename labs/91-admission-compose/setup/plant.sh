#!/usr/bin/env bash
set -e
P=/home/analista/shipyard
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/deploy.sh" "$P/admit.sh"
chown -R analista:analista "$P"
cd "$P"
docker compose up -d --build
echo "Lab 91 plantado."
