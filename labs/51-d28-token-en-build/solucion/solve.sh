#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/notify
cat > app/Dockerfile <<'EOF'
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
CMD ["python", "-u", "app.py"]
EOF
install -d -m 0700 -o analista -g analista secrets
install -m 0600 -o analista -g analista /dev/null secrets/notify_token.txt
echo 'ntf_live_2c8e5a17f9b4' > secrets/notify_token.txt
cat > compose.yaml <<'EOF'
name: notify

services:
  gateway:
    image: notify/gateway:1.0
    environment:
      ROLE: gateway
    restart: unless-stopped

  notifier:
    image: notify/app:1.0
    build: ./app
    environment:
      ROLE: notifier
      NOTIFY_TOKEN_FILE: /run/secrets/notify_token
    secrets:
      - notify_token
    restart: unless-stopped

secrets:
  notify_token:
    file: ./secrets/notify_token.txt
EOF
chown -R analista: app compose.yaml
docker compose up -d --build
docker image prune -f >/dev/null
docker builder prune -af >/dev/null
sleep 5
