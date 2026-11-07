#!/usr/bin/env bash
# Lab 181: cada despliegue corta peticiones. docker stop tarda 10 s y acaba en
# SIGKILL (137): el shell es PID 1 y no reenvía SIGTERM, la app no lo maneja,
# y cuando Python pasa a ser PID 1 nadie recoge los procesos huérfanos (zombis).
set -e
A=/home/analista/app
mkdir -p $A

cat > $A/app.py <<'PY'
"""API de informes. /lento genera un informe (2 s); /tarea lanza un trabajo en segundo plano."""
import subprocess, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


class H(BaseHTTPRequestHandler):
    def _ok(self, body):
        b = body.encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/lento":
            time.sleep(2)
            return self._ok("informe listo\n")
        if self.path == "/tarea":
            # El trabajo se desengancha: el sh termina y su hijo queda huérfano.
            subprocess.Popen(["sh", "-c", "sleep 0.2 &"]).wait()
            return self._ok("tarea lanzada\n")
        return self._ok("ok\n")

    def log_message(self, *a):
        pass


log("arrancando en :8000")
ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
PY
cat > $A/entrypoint.sh <<'SH'
#!/bin/bash
echo "preparando configuración..."
sleep 0.2
python app.py
SH
chmod 0755 $A/entrypoint.sh
cat > $A/Dockerfile <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY . .
CMD ./entrypoint.sh
DF
cat > $A/compose.yaml <<'Y'
services:
  app:
    build: .
    image: informes:dev
    ports:
      - "127.0.0.1:8000:8000"
Y
chown -R analista:analista $A

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Apagado limpio

En cada despliegue, los usuarios que estaban generando un informe (/lento,
2 segundos) reciben un error. Y "docker compose stop" tarda 10 segundos.

  cd ~/app && docker compose up -d --build
  curl localhost:8000/lento &  sleep 0.5;  time docker compose stop
  docker compose ps -a        # mira el código de salida

Objetivo:
1. docker compose stop tarda menos de 5 s y el contenedor sale con código 0.
2. Una petición en curso cuando llega la parada termina bien (200).
3. La app escribe "apagado limpio" en su log al salir.
4. Ningún proceso zombi dentro del contenedor tras usar /tarea.
5. Dockerfile con CMD/ENTRYPOINT en forma exec (JSON).

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
cd $A && docker compose build -q && docker compose up -d
echo "Lab 181 plantado."
