#!/usr/bin/env bash
set -e
P=/home/analista/shop-ci
mkdir -p "$P/jobs" "$P/logs" "$P/dist"
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/run-ci.sh" "$P/jobs/"*.sh
chown -R analista:analista "$P"
# Última ejecución "en PR": el token quedó en el log.
(
  cd "$P"
  su -s /bin/bash analista -c './run-ci.sh'
) || true
echo "Lab 87 plantado."
