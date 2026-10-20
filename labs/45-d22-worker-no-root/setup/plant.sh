#!/usr/bin/env bash
# Lab 45 (Día 22): un worker que procesa ficheros subidos por usuarios corre como root.
set -e
P=/home/analista/media
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t media/thumbnailer:1.0 ./thumbnailer >/dev/null
chown -R analista:analista "$P"
mkdir -p jobs/in jobs/out jobs/done
chown -R root:root jobs
chmod 0755 jobs jobs/*
for i in 1 2; do echo "imagen $i" > jobs/in/foto-$i.jpg; done
docker compose up -d
echo "Lab 45 plantado."
