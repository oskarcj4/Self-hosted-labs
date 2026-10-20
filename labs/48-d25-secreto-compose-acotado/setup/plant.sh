#!/usr/bin/env bash
# Lab 48 (Día 25): un secreto de Compose montado en todos los servicios,
# aunque sólo uno lo usa.
set -e
P=/home/analista/analytics
mkdir -p "$P/secrets"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t analytics/app:1.0 ./app >/dev/null
echo "rpt_tok_51c9e07a2b" > secrets/api_token.txt
chown -R analista:analista "$P"
chmod 0700 secrets
chmod 0600 secrets/api_token.txt
docker compose up -d
echo "Lab 48 plantado."
