#!/usr/bin/env bash
# Lab 41 (Día 18): el endpoint de métricas está publicado en el host "para que
# el scraper lo vea", aunque el scraper está en la misma red de Compose.
set -e
P=/home/analista/shop
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t shop/app:1.0 ./app >/dev/null
docker compose up -d
chown -R analista:analista "$P"
echo "Lab 41 plantado."
