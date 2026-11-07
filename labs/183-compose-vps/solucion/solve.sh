#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/vps
docker compose down -t 2 || true

mkdir -p secretos
( umask 077; head -c 24 /dev/urandom | base64 | tr -d '/+=' > secretos/db_password.txt )
printf 'secretos/\n' > .gitignore

cat > compose.yaml <<'Y'
# Producción en un VPS: sólo el proxy hacia fuera, datos en un volumen,
# contraseña como secret, arranque ordenado por salud y logs con límite.
x-logs: &logs
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s
    logging: *logs

  app:
    build: ./app
    image: pedidos:1.0.0
    restart: unless-stopped
    environment:
      DB_HOST: db
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/salud', timeout=3)"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
    logging: *logs

  proxy:
    image: nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      app:
        condition: service_healthy
    logging: *logs

volumes:
  pgdata:

secrets:
  db_password:
    file: ./secretos/db_password.txt
Y
docker compose config -q
docker compose up -d --build --wait
curl -s -X POST 'localhost/pedidos?producto=taza'; echo
curl -s localhost/pedidos; echo
docker compose ps
echo "solve.sh completado."
