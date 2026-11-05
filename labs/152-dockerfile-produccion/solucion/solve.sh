#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como analista.
set -e
APP=/home/analista/app

cat > "$APP/Dockerfile" <<'DF'
# ---- etapa de build ----
FROM python:3.12-slim-bookworm AS build
WORKDIR /app
COPY app.py .
RUN python -m compileall -q app.py

# ---- etapa final ----
FROM python:3.12-slim-bookworm AS final
LABEL org.opencontainers.image.title="allsafe-api" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.source="https://allsafe.example/allsafe-api"
RUN useradd --system --no-create-home --uid 10001 appuser
WORKDIR /app
COPY --from=build /app/app.py /app/app.py
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1
CMD ["python", "app.py"]
DF

cat > "$APP/.dockerignore" <<'DI'
.git
.gitignore
__pycache__/
*.pyc
README.txt
DI

cd "$APP"
docker build -t app:prod .
echo "solve.sh completado."
