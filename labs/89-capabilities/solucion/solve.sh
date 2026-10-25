#!/usr/bin/env bash
set -e
cd /home/analista/caps
cat > compose.yaml <<'EOF'
name: caps

services:
  api:
    image: shop/api:1.0
    build: ./api
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF
chown analista: compose.yaml
docker compose up -d
sleep 2
