#!/usr/bin/env bash
# Lab 159: el pipeline de la API sólo hace build + deploy con 'latest'.
# Sin pruebas, sin escaneo, sin registro, sin verificación ni rollback; y hay
# un token de GitHub en el código. El alumno construye el pipeline completo.
set -e
H=/home/analista
A=$H/api
mkdir -p "$A/tests" "$A/ci" /var/lib/ci/logs
chown -R analista:analista /var/lib/ci

cat > "$A/app.py" <<'PY'
"""API de pedidos (stdlib). Escucha en $PORT (8080 por defecto)."""
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer

from config import GITHUB_TOKEN  # noqa: F401  (se usa para crear issues)

VERSION = os.environ.get("APP_VERSION", "dev")


def salud():
    return {"status": "ok"}


def total(lineas):
    return round(sum(l["precio"] * l["cantidad"] for l in lineas), 2)


class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, salud())
        else:
            self._send(200, {"app": "pedidos", "version": VERSION})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), H).serve_forever()
PY
TOKEN="ghp_$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)"
cat > "$A/config.py" <<PY
# Configuración de la API.
GITHUB_TOKEN = "$TOKEN"
PY
cat > "$A/tests/__init__.py" <<'PY'
PY
cat > "$A/tests/test_app.py" <<'PY'
import unittest

from app import salud, total


class TestApp(unittest.TestCase):
    def test_salud(self):
        self.assertEqual(salud(), {"status": "ok"})

    def test_total(self):
        self.assertEqual(total([{"precio": 2.5, "cantidad": 2}, {"precio": 1, "cantidad": 3}]), 8.0)


if __name__ == "__main__":
    unittest.main()
PY
cat > "$A/Dockerfile" <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY app.py config.py ./
RUN useradd -r -u 10001 app
USER app
EXPOSE 8080
CMD ["python", "app.py"]
DF
cat > "$A/.dockerignore" <<'TXT'
.git
tests
ci
__pycache__
TXT
cat > "$A/ci/deploy.sh" <<'SH'
#!/usr/bin/env bash
# Despliega la imagen $1 como contenedor 'api' en 127.0.0.1:8080.
set -euo pipefail
IMG="$1"
docker rm -f api >/dev/null 2>&1 || true
docker run -d --name api --restart=unless-stopped -p 127.0.0.1:8080:8080 "$IMG" >/dev/null
echo "desplegado $IMG"
SH
chmod 0755 "$A/ci/deploy.sh"
cat > "$A/.woodpecker.yaml" <<'YML'
# Pipeline de la API (Woodpecker, backend local: 'image' es el shell del step).
skip_clone: true

steps:
  - name: clone
    image: bash
    commands:
      - git clone -q "$CI_REPO_CLONE_URL" .
      - git checkout -q "$CI_COMMIT_SHA"

  - name: build
    image: bash
    commands:
      - docker build -q -t api:latest .

  - name: deploy
    image: bash
    commands:
      - bash ci/deploy.sh api:latest
YML
cat > "$A/README.md" <<'MD'
# API de pedidos

- Pruebas: `python3 -m unittest -v`
- Pipeline: `.woodpecker.yaml` (lánzalo con `ci-run`, logs con `ci-logs`)
- Registro de imágenes: `localhost:5000`
- Producción: contenedor `api` en `127.0.0.1:8080` (`/health`)
MD
chown -R analista:analista "$A"
cd "$A"
runuser -u analista -- git init -q -b main
runuser -u analista -- git config user.name "Analista"
runuser -u analista -- git config user.email analista@tienda.local
runuser -u analista -- git add -A
runuser -u analista -- git commit -qm "API de pedidos + pipeline inicial"
runuser -u analista -- ci-run >/dev/null 2>&1 || { echo "el pipeline inicial debía pasar"; exit 1; }
for _ in $(seq 1 20); do curl -fs http://127.0.0.1:8080/health >/dev/null && break; sleep 1; done
curl -fs http://127.0.0.1:8080/health >/dev/null

cat > $H/TAREA.txt <<'TXT'
TAREA · Pipeline completo (repo ~/api)

Hoy el pipeline sólo hace "build latest + deploy". Si el código rompe, se
despliega igual; si la app no arranca, producción queda caída; y nadie sabe qué
versión corre. Además hay un token de GitHub en config.py.

Deja .woodpecker.yaml con estos steps, EN ESTE ORDEN tras 'clone':
  test     -> python3 -m unittest (si falla, no se construye nada)
  scan     -> gitleaks dir . (si hay secretos, se para)
  build    -> imagen localhost:5000/api:<12 primeros caracteres del commit>
  publish  -> docker push de esa imagen al registro local
  deploy   -> despliega ESA imagen como contenedor 'api' (127.0.0.1:8080),
              comprueba /health y, si no responde en ~20 s, vuelve a la imagen
              que corría antes (rollback) y hace fallar el pipeline.

Además: quita el token de config.py (léelo de la variable GITHUB_TOKEN).

Haz commit y deja el pipeline en verde (ci-run). El check probará también un
commit que rompe las pruebas y otro que rompe el arranque.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 159 plantado."
