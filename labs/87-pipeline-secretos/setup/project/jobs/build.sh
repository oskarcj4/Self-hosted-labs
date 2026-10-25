#!/usr/bin/env bash
set -euo pipefail
echo "building shop"
echo "token=${DEPLOY_TOKEN:-}"
# "Para poder publicar la imagen desde el runner"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock python:3.12-alpine \
  python -c 'print("build-via-sock")'
mkdir -p dist
echo shop-ok > dist/shop.txt
