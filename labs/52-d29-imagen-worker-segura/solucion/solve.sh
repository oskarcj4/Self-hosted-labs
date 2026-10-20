#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/reports
cat > app/Dockerfile <<'EOF'
FROM python:3.12-alpine
ENV PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY worker.py .
COPY data/ data/
CMD ["python", "-u", "worker.py"]
EOF
printf 'debug/\ntests/\n.env*\nDockerfile\n.dockerignore\n' > app/.dockerignore
chown -R analista: app
docker compose up -d --build
docker image prune -f >/dev/null
sleep 3
