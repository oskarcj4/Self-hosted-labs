#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/logs
cat > compose.yaml <<'EOF'
name: logs

services:
  collector:
    image: logs/collector:0.9
    build: ./collector
    volumes:
      - ./logs:/logs:ro
      - ./out:/out
    restart: unless-stopped
EOF
chown analista: compose.yaml
docker compose up -d
sleep 4
