#!/usr/bin/env bash
set -e
cd /home/analista/edge
cat > compose.yaml <<'EOF'
name: edge

services:
  api:
    image: shop/edge:1.0
    build: ./api
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data:ro
    restart: unless-stopped
EOF
chown analista: compose.yaml
docker compose up -d
sleep 2
