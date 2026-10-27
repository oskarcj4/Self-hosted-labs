#!/usr/bin/env bash
set -e
P=/home/analista/trace-ci
mkdir -p "$P" /etc/ci
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/run-ci.sh" "$P/jobs/"*.sh "$P/bin/push"
chmod 600 "$P/secrets/deploy_token"
printf '%s' tclab-trace-token-do-not-log | sha256sum | cut -d' ' -f1 > /etc/ci/token.sha256
chmod 644 /etc/ci/token.sha256
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./run-ci.sh" || true
echo "Lab 94 plantado."
