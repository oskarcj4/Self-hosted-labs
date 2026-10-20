#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/media
cat > thumbnailer/Dockerfile <<'EOF'
FROM python:3.12-alpine
RUN addgroup -S -g 10001 thumb && adduser -S -D -H -u 10001 -G thumb thumb
WORKDIR /app
COPY worker.py .
USER 10001:10001
CMD ["python", "-u", "worker.py"]
EOF
chown -R 10001:10001 jobs
chmod 0750 jobs jobs/*
docker compose up -d --build
sleep 3
