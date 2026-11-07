#!/usr/bin/env bash
# Lab 183: el compose "de mi portátil" se copió tal cual al VPS de producción.
# Base de datos expuesta a internet, contraseña en el YAML, datos que se pierden
# con un down, la app arranca antes que la base de datos y muere, sin reinicios
# ni límites de logs. El alumno lo deja listo para un VPS.
set -e
V=/home/analista/vps
mkdir -p $V/app/wheels
cp /opt/wheels/*.whl $V/app/wheels/

cat > $V/app/app.py <<'PY'
"""API de pedidos. GET /salud, GET /pedidos, POST /pedidos?producto=X"""
import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import pg8000.native


def password():
    # DB_PASSWORD_FILE (p. ej. un secret en /run/secrets/...) tiene prioridad sobre DB_PASSWORD.
    f = os.environ.get("DB_PASSWORD_FILE")
    return open(f).read().strip() if f else os.environ["DB_PASSWORD"]


def conn():
    return pg8000.native.Connection(user=os.environ.get("DB_USER", "postgres"), password=password(),
                                    host=os.environ.get("DB_HOST", "db"),
                                    database=os.environ.get("DB_NAME", "postgres"), timeout=5)


class H(BaseHTTPRequestHandler):
    def _r(self, code, obj):
        b = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        try:
            c = conn()
            if self.path == "/salud":
                c.run("SELECT 1"); c.close()
                return self._r(200, {"estado": "ok"})
            if self.path == "/pedidos":
                filas = c.run("SELECT id, producto FROM pedidos ORDER BY id"); c.close()
                return self._r(200, [{"id": i, "producto": p} for i, p in filas])
            c.close()
            return self._r(404, {"error": "no existe"})
        except Exception as e:
            return self._r(503, {"error": str(e)})

    def do_POST(self):
        u = urlparse(self.path)
        if u.path != "/pedidos":
            return self._r(404, {"error": "no existe"})
        prod = parse_qs(u.query).get("producto", ["sin nombre"])[0]
        try:
            c = conn()
            fila = c.run("INSERT INTO pedidos (producto) VALUES (:p) RETURNING id", p=prod); c.close()
            return self._r(201, {"id": fila[0][0], "producto": prod})
        except Exception as e:
            return self._r(503, {"error": str(e)})

    def log_message(self, fmt, *a):
        print(self.address_string(), fmt % a, flush=True)


# Al arrancar crea la tabla. Si la base de datos aún no acepta conexiones, falla y sale.
c = conn()
c.run("CREATE TABLE IF NOT EXISTS pedidos (id serial PRIMARY KEY, producto text NOT NULL)")
c.close()
print("pedidos escuchando en :8000", flush=True)
ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
PY
cat > $V/app/Dockerfile <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY wheels/ /wheels/
RUN pip install --no-cache-dir --no-index --find-links /wheels pg8000==1.31.2
COPY app.py .
CMD ["python", "app.py"]
DF
cat > $V/nginx.conf <<'N'
server {
    listen 80;
    location / {
        proxy_pass http://app:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
N
cat > $V/compose.yaml <<'Y'
# Copiado del portátil de desarrollo.
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: tienda123
    ports:
      - "5432:5432"

  app:
    build: ./app
    environment:
      DB_HOST: db
      DB_PASSWORD: tienda123
    ports:
      - "8000:8000"
    depends_on:
      - db

  proxy:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
Y
chown -R analista:analista $V

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Compose para un VPS

~/vps/compose.yaml se copió del portátil al VPS de producción. Pruébalo:
  cd ~/vps && docker compose up -d --build && docker compose ps -a
  curl -X POST 'localhost/pedidos?producto=taza'; curl localhost/pedidos

Déjalo listo para producción:
1. Sólo el proxy publica un puerto (80). Ni la base de datos ni la app.
2. Los datos de PostgreSQL sobreviven a "docker compose down" (volumen con nombre).
3. Contraseña fuera de compose.yaml y fuera de las variables de entorno de
   los contenedores: secrets de Compose (fichero) + POSTGRES_PASSWORD_FILE /
   DB_PASSWORD_FILE. (Y genera una contraseña nueva: la vieja está en git.)
4. La app no arranca hasta que la base de datos está sana: healthcheck en db
   y depends_on con condition: service_healthy. Healthcheck también en la app.
5. Todos los servicios con política de reinicio (unless-stopped o always).
6. Logs con límite: driver json-file con max-size (y max-file) en todos.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
cd $V && docker compose build -q && (docker compose up -d >/dev/null 2>&1 || true)
echo "Lab 183 plantado."
