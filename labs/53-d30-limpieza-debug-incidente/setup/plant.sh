#!/usr/bin/env bash
# Lab 53 (Día 30): tras un incidente quedaron un override con AUTH_BYPASS y un
# contenedor de "shell de depuración" publicado y con / del host montado.
set -e
P=/home/analista/portal
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t portal/app:5.0 ./app >/dev/null
echo "ADMIN_KEY=adm-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > .env
chmod 0600 .env
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 53 plantado."
