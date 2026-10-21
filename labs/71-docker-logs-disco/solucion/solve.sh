#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
truncate -s 0 "$(docker inspect -f '{{.LogPath}}' pedidos-worker-1)"
cd /srv/pedidos
cat > compose.yaml <<'EOF'
name: pedidos

x-logging: &logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  api:
    image: python:3.12-alpine
    command: ["python", "-u", "/app/api.py"]
    volumes:
      - ./app:/app:ro
    ports:
      - "127.0.0.1:8000:8000"
    restart: unless-stopped
    logging: *logging

  worker:
    image: python:3.12-alpine
    command: ["python", "-u", "/app/worker.py"]
    environment:
      LOG_LEVEL: INFO
      BACKLOG: "1150000"
    volumes:
      - ./app:/app:ro
    restart: unless-stopped
    logging: *logging
EOF
docker compose up -d
sleep 2
