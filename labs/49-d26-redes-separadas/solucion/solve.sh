#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/store
cat > compose.yaml <<'EOF'
name: store

services:
  web:
    image: store/app:1.0
    build: ./app
    environment:
      ROLE: web
    ports:
      - "8080:8080"
    networks: [frontend]
    restart: unless-stopped

  api:
    image: store/app:1.0
    environment:
      ROLE: api
    networks: [frontend, backend]
    restart: unless-stopped

  db:
    image: store/app:1.0
    environment:
      ROLE: db
    networks: [backend]
    restart: unless-stopped

networks:
  frontend:
  backend:
    internal: true
EOF
chown analista: compose.yaml
docker compose up -d --remove-orphans
sleep 2
