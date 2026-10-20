#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/files
install -d -m 0700 -o analista -g analista secrets
install -m 0600 -o analista -g analista /dev/null secrets/uploader_token.txt
grep -o 'upl_live_[a-z0-9]*' compose.yaml > secrets/uploader_token.txt
cat > compose.yaml <<'EOF'
name: files

services:
  storage:
    image: files/app:1.0
    build: ./app
    environment:
      ROLE: storage
    restart: unless-stopped

  uploader:
    image: files/app:1.0
    environment:
      ROLE: uploader
      UPLOADER_API_TOKEN_FILE: /run/secrets/uploader_token
    secrets:
      - uploader_token
    restart: unless-stopped

secrets:
  uploader_token:
    file: ./secrets/uploader_token.txt
EOF
chown analista: compose.yaml
docker compose up -d
sleep 5
