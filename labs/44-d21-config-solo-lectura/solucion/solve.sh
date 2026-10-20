#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/edge
rm -f config/.runtime-cache
cat > compose.yaml <<'EOF'
name: edge

services:
  gateway:
    image: edge/gateway:3.1
    build: ./gateway
    ports:
      - "8080:8080"
    environment:
      GATEWAY_CACHE_DIR: /var/cache/gateway
    volumes:
      - ./config:/etc/gateway:ro
    tmpfs:
      - /var/cache/gateway
    restart: unless-stopped
EOF
chown analista: compose.yaml
docker compose up -d
sleep 2
