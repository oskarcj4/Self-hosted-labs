#!/usr/bin/env bash
# Lab 51 (Día 28): el token se mete en la imagen durante el build (ARG/ENV/RUN).
set -e
P=/home/analista/notify
mkdir -p "$P"
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
SHA=$(printf '%s' "ntf_live_2c8e5a17f9b4" | sha256sum | cut -d' ' -f1)
sed -i "s/^TOKEN_SHA = \"[0-9a-f]*\"/TOKEN_SHA = \"$SHA\"/" app/app.py
# La pasarela es "otro equipo": su imagen se construye aparte y sin el token.
mkdir -p /tmp/gw && cp app/app.py /tmp/gw/ \
  && printf 'FROM python:3.12-alpine\nWORKDIR /app\nCOPY app.py .\nCMD ["python","-u","app.py"]\n' > /tmp/gw/Dockerfile
docker build -q -t notify/gateway:1.0 /tmp/gw >/dev/null
rm -rf /tmp/gw
docker build -q -t notify/app:1.0 ./app >/dev/null
chown -R analista:analista "$P"
docker compose up -d
echo "Lab 51 plantado."
