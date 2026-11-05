#!/usr/bin/env bash
# Lab 152: una app con un Dockerfile "de desarrollo" malo. El alumno lo
# reescribe como Dockerfile de producción.
set -e
APP=/home/analista/app
mkdir -p "$APP"

# App mínima sin dependencias externas (http.server de la stdlib).
cat > "$APP/app.py" <<'PY'
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = os.environ.get("APP_VERSION", "1.0.0")

class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path == "/healthz":
            self._send(200, {"status": "ok"})
        else:
            self._send(200, {"app": "allsafe-api", "version": VERSION})
    def log_message(self, *a):
        pass

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8000), H).serve_forever()
PY

# Dockerfile MALO de partida (una sola etapa, root, sin healthcheck ni labels).
cat > "$APP/Dockerfile" <<'DF'
FROM python:3.12
COPY . /app
WORKDIR /app
CMD ["python", "app.py"]
DF

cat > "$APP/README.txt" <<'TXT'
API "allsafe-api". El Dockerfile actual es de desarrollo: usa la imagen gorda
python:3.12, corre como root, no declara puerto, no tiene healthcheck ni
metadatos. Conviértelo en un Dockerfile de PRODUCCIÓN.
TXT

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Dockerfile de producción para allsafe-api (~/app)

Reescribe ~/app/Dockerfile para que sea de producción. Debe cumplir:
1. Multi-stage: una etapa de build y una final (dos o más 'FROM').
2. Imagen final ligera: base python:3.12-slim-bookworm (ya está precargada).
3. Usuario NO root: crea un usuario y ponlo con USER.
4. HEALTHCHECK que consulte /healthz en el puerto 8000.
5. Metadatos OCI: al menos una etiqueta 'org.opencontainers.image.*'.
6. EXPOSE 8000 y CMD que arranque app.py.
Además crea ~/app/.dockerignore que excluya .git y __pycache__.

Construye y prueba:
  cd ~/app && docker build -t app:prod .
  docker run --rm -d -p 8000:8000 --name t app:prod
  curl -s localhost:8000/healthz ; docker rm -f t
Comprueba:  bash /opt/lab/check.sh
TXT
chown -R analista:analista /home/analista
echo "Lab 152 plantado."
