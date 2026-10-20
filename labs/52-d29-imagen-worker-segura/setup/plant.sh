#!/usr/bin/env bash
# Lab 52 (Día 29): imagen del worker construida "en modo desarrollo": base sin
# fijar, DEBUG=1, puerto de depuración y ficheros de depuración/pruebas dentro.
set -e
P=/home/analista/reports
mkdir -p "$P/out"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
# Sin acceso a Docker Hub: "python:3-alpine" apunta a la 3.12 precargada.
docker tag python:3.12-alpine python:3-alpine
docker build -q -t reports/worker:latest ./app >/dev/null
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 52 plantado."
