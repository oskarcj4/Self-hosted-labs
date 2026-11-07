#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/api
cat > config.py <<'PY'
# Configuración de la API: los secretos llegan por entorno, nunca en el código.
import os

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
PY

cat > ci/build.sh <<'SH'
#!/usr/bin/env bash
# build.sh <sha> — construye localhost:5000/api:<12 primeros del sha>.
set -euo pipefail
TAG="localhost:5000/api:${1:0:12}"
docker build -q --label org.opencontainers.image.revision="$1" -t "$TAG" .
echo "$TAG" > .image
SH
cat > ci/deploy.sh <<'SH'
#!/usr/bin/env bash
# deploy.sh <imagen> — despliega como 'api', verifica /health y, si falla, rollback.
set -uo pipefail
NEW="$1"
OLD=$(docker inspect -f '{{.Config.Image}}' api 2>/dev/null || true)
run(){ docker rm -f api >/dev/null 2>&1 || true
       docker run -d --name api --restart=unless-stopped -p 127.0.0.1:8080:8080 "$1" >/dev/null; }
run "$NEW"
for _ in $(seq 1 20); do
  if curl -fs http://127.0.0.1:8080/health >/dev/null; then echo "desplegado $NEW (sano)"; exit 0; fi
  sleep 1
done
echo "ERROR: $NEW no responde en /health"
if [ -n "$OLD" ]; then
  echo "ROLLBACK a $OLD"; run "$OLD"
fi
exit 1
SH
chmod 0755 ci/*.sh

cat > .woodpecker.yaml <<'YML'
# Pipeline de la API (Woodpecker, backend local: 'image' es el shell del step).
skip_clone: true

steps:
  - name: clone
    image: bash
    commands:
      - git clone -q "$CI_REPO_CLONE_URL" .
      - git checkout -q "$CI_COMMIT_SHA"

  - name: test
    image: bash
    commands:
      - python3 -m unittest -v

  - name: scan
    image: bash
    commands:
      - gitleaks dir . --no-banner

  - name: build
    image: bash
    commands:
      - bash ci/build.sh "$CI_COMMIT_SHA"

  - name: publish
    image: bash
    commands:
      - docker push -q "$(cat .image)"

  - name: deploy
    image: bash
    commands:
      - bash ci/deploy.sh "$(cat .image)"
YML
git add -A
git commit -qm "Pipeline completo: test, scan, build por commit, publish y deploy con rollback"
ci-run
echo "solve.sh completado."
