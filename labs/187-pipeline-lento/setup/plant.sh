#!/usr/bin/env bash
# Lab 187: un pipeline que tarda casi un minuto en cada commit, aunque sólo
# cambie una línea. Dependencias reinstaladas siempre, capas de Docker en mal
# orden, --no-cache y 150 MB de datos en el contexto de build.
set -e
H=/home/analista
A=$H/api
mkdir -p "$A/tests" "$A/ci" "$A/datos" "$A/wheels" /var/lib/ci/logs /var/cache/ci
cp /opt/wheels/*.whl "$A/wheels/"
chown -R analista:analista /var/lib/ci /var/cache/ci

cat > "$A/app.py" <<'PY'
"""API de entregas (stdlib + python-dateutil). Escucha en $PORT (8080)."""
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

from dateutil.parser import isoparse
from dateutil.relativedelta import relativedelta

VERSION = "1.0.0"


def entrega(desde, dias_habiles=3):
    """Fecha de entrega: N días hábiles (lunes a viernes) después de 'desde'."""
    d = isoparse(desde)
    while dias_habiles:
        d += relativedelta(days=1)
        if d.weekday() < 5:
            dias_habiles -= 1
    return d.date().isoformat()


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/entrega":
            body = {"entrega": entrega(parse_qs(u.query).get("desde", ["2026-01-05"])[0])}
        else:
            body = {"app": "entregas", "version": VERSION}
        b = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), H).serve_forever()
PY
cat > "$A/requirements.txt" <<'TXT'
python-dateutil==2.9.0.post0
six==1.16.0
TXT
cat > "$A/ci/instalar-deps.sh" <<'SH'
#!/usr/bin/env bash
# Instala requirements.txt (desde wheels/) en el directorio $1, o en el sistema
# si no se indica. En el lab no hay red: los 20 s simulan la descarga.
set -euo pipefail
echo "instalar-deps: descargando dependencias de requirements.txt..."
sleep 20
export PIP_BREAK_SYSTEM_PACKAGES=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore
python3 -m pip install -q --no-index --find-links wheels -r requirements.txt ${1:+--target "$1"}
echo "instalar-deps: listo"
SH
chmod 0755 "$A/ci/instalar-deps.sh"
cat > "$A/tests/__init__.py" <<'PY'
PY
cat > "$A/tests/test_app.py" <<'PY'
import unittest

from app import entrega


class TestEntrega(unittest.TestCase):
    def test_entre_semana(self):
        self.assertEqual(entrega("2026-01-05"), "2026-01-08")   # lunes -> jueves

    def test_salta_fin_de_semana(self):
        self.assertEqual(entrega("2026-01-08"), "2026-01-13")   # jueves -> martes


if __name__ == "__main__":
    unittest.main()
PY
# Exportaciones que alguien dejó en el repo "para las pruebas manuales".
for i in 1 2 3; do head -c 50M /dev/urandom > "$A/datos/export-2025-0$i.bin"; done

cat > "$A/Dockerfile" <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY . .
RUN bash ci/instalar-deps.sh
USER 10001
EXPOSE 8080
CMD ["python", "app.py"]
DF
cat > "$A/.woodpecker.yaml" <<'YML'
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
      - bash ci/instalar-deps.sh .deps

  - name: test
    image: bash
    commands:
      - PYTHONPATH=.deps python3 -m unittest -v

  - name: build
    image: bash
    commands:
      # --no-cache: lo puso alguien hace meses "porque a veces no cogía los cambios"
      - docker build --no-cache -t "api:$CI_COMMIT_SHA" .
YML
cat > "$A/.gitignore" <<'TXT'
.deps/
__pycache__/
TXT
cat > "$A/README.md" <<'MD'
# API de entregas

- Pruebas: `PYTHONPATH=.deps python3 -m unittest -v`
- Pipeline: `.woodpecker.yaml` (lánzalo con `ci-run`, logs con `ci-logs`, historial con `ci-logs -l`)
- La imagen se etiqueta `api:<sha del commit>`.
MD
chown -R analista:analista "$A"
cd "$A"
runuser -u analista -- git init -q -b main
runuser -u analista -- git config user.name "Analista"
runuser -u analista -- git config user.email analista@tienda.local
runuser -u analista -- git add -A
runuser -u analista -- git commit -qm "API de entregas + pipeline"
runuser -u analista -- ci-run >/dev/null 2>&1 || { echo "el pipeline inicial debía pasar"; exit 1; }

cat > $H/TAREA.txt <<'TXT'
TAREA · Pipeline lento (repo ~/api)

Cada commit tarda casi un minuto en CI, aunque sólo cambie una línea de
app.py. Mira el log (ci-logs) y el historial (ci-logs -l): ¿en qué se va el tiempo?

Objetivo: un commit que sólo toca código tarda MENOS DE 25 s, sin perder nada:
  - los steps deps, test y build siguen existiendo y la imagen sigue
    siendo api:$CI_COMMIT_SHA, con el código nuevo dentro;
  - si cambia requirements.txt, las dependencias se reinstalan (en los tests
    y en la imagen); una caché que nunca se invalida es un bug;
  - un test roto sigue poniendo el pipeline en rojo;
  - nada de borrar los datos del repo: no deben entrar en la imagen.

Pistas: orden de las capas del Dockerfile, .dockerignore, --no-cache, y una
caché de dependencias en /var/cache/ci con la clave = hash de requirements.txt.

Haz commit y lanza ci-run. Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 187 plantado."
