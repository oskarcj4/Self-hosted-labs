#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# TODO: no subir nada que admit.sh no haya aceptado
docker compose up -d --build
