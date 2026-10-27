#!/usr/bin/env bash
set -e
P=/home/analista/iac
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/scan.sh" "$P/test-scan.sh"
chown -R analista:analista "$P"
cd "$P"
docker compose up -d --build
echo "Lab 93 plantado."
