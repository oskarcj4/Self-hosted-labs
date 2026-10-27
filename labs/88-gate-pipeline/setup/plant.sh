#!/usr/bin/env bash
set -e
P=/home/analista/gate-ci
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/run-ci.sh" "$P/jobs/"*.sh
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./run-ci.sh" || true
echo "Lab 88 plantado."
