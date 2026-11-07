#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/api

# 1. Capas: primero lo que cambia poco (dependencias), al final el código.
cat > Dockerfile <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
# Esta capa sólo se rehace si cambian requirements.txt, los wheels o el script.
COPY requirements.txt ./
COPY wheels/ wheels/
COPY ci/instalar-deps.sh ci/
RUN bash ci/instalar-deps.sh && rm -rf wheels
# El código, lo último: cambiarlo no invalida las dependencias.
COPY app.py ./
USER 10001
EXPOSE 8080
CMD ["python", "app.py"]
DF

# 2. Fuera del contexto de build lo que no necesita la imagen.
cat > .dockerignore <<'TXT'
.git
datos/
tests/
.deps/
__pycache__/
*.pyc
TXT

# 3. Caché de dependencias para los tests, con clave = hash de requirements.txt
#    (y de los wheels): si cambian, la clave cambia y se reinstala. En un script:
#    Woodpecker sustituye $VARIABLES en el YAML antes de ejecutar.
cat > ci/deps.sh <<'SH'
#!/usr/bin/env bash
# Deja en .deps las dependencias de requirements.txt, desde la caché si ya existen.
set -euo pipefail
CLAVE=$(cat requirements.txt wheels/*.whl ci/instalar-deps.sh | sha256sum | cut -c1-16)
CACHE=/var/cache/ci/deps-$CLAVE
if [ -d "$CACHE" ]; then
  echo "deps: caché $CLAVE"
else
  rm -rf "$CACHE.tmp"
  bash ci/instalar-deps.sh "$CACHE.tmp"
  mv "$CACHE.tmp" "$CACHE"                    # atómico: nunca queda una caché a medias
fi
ln -sfn "$CACHE" .deps
SH
chmod +x ci/deps.sh

cat > .woodpecker.yaml <<'YML'
# Pipeline de la API (Woodpecker, backend local: 'image' es el shell del step).
skip_clone: true

steps:
  - name: clone
    image: bash
    commands:
      - git clone -q "$CI_REPO_CLONE_URL" .
      - git checkout -q "$CI_COMMIT_SHA"

  - name: deps
    image: bash
    commands:
      - bash ci/deps.sh

  - name: test
    image: bash
    commands:
      - PYTHONPATH=.deps python3 -m unittest -v

  - name: build
    image: bash
    commands:
      - docker build -t "api:$CI_COMMIT_SHA" .
YML

git add -A
git commit -qm "ci: caché de dependencias, capas ordenadas y .dockerignore"
ci-run >/dev/null || true      # el primero llena las cachés
echo "--- segundo commit (sólo código)"
sed -i 's/^VERSION = .*/VERSION = "1.0.1"/' app.py
git commit -qam "versión 1.0.1"
ci-run | tail -2
ci-logs -l | tail -3
echo "solve.sh completado."
