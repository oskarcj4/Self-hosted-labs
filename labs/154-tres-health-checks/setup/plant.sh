#!/usr/bin/env bash
# Lab 154: la app solo tiene un /health que siempre devuelve 200, aunque su
# dependencia (la base de datos) esté caída. El alumno implementa las tres
# sondas: startup, liveness y readiness, con dependencia real.
set -e
install -d -m 0755 /opt/allsafe

# Dependencia simulada: un servicio que escucha en 127.0.0.1:5432.
cat > /opt/allsafe/db.py <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 5432)); s.listen(16)
while True:
    c, _ = s.accept(); c.close()
PY
cat > /etc/systemd/system/allsafe-db.service <<'U'
[Unit]
Description=allsafe-db (dependencia simulada)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/allsafe/db.py
Restart=always

[Install]
WantedBy=multi-user.target
U

# App MALA de partida: un solo /health que miente (siempre 200).
cat > /opt/allsafe/app.py <<'PY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        # MAL: una sola sonda que siempre dice "ok", ignore la base de datos.
        body = json.dumps({"status":"ok"}).encode()
        self.send_response(200); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
    def log_message(self,*a): pass

HTTPServer(("127.0.0.1",8080), H).serve_forever()
PY
cat > /etc/systemd/system/allsafe-api.service <<'U'
[Unit]
Description=allsafe-api
After=network.target allsafe-db.service

[Service]
ExecStart=/usr/bin/python3 /opt/allsafe/app.py
Restart=always

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now allsafe-db.service >/dev/null 2>&1 || true
systemctl enable --now allsafe-api.service >/dev/null 2>&1 || true
chown -R analista:analista /opt/allsafe

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Tres health checks para allsafe-api

/opt/allsafe/app.py solo tiene /health y SIEMPRE devuelve 200, aunque la base
de datos (allsafe-db, 127.0.0.1:5432) esté caída. Así el orquestador manda
tráfico a una instancia rota. Implementa las tres sondas:

  /livez    liveness  -> 200 si el proceso está vivo (no mira dependencias).
  /startup  startup   -> 200 cuando terminó el arranque/calentamiento.
  /readyz   readiness -> 200 solo si terminó el arranque Y la base de datos
                         responde (conecta a 127.0.0.1:5432); si no, 503.

Clave: si la base de datos cae, /readyz debe dar 503 (deja de recibir tráfico)
pero /livez debe seguir en 200 (no reinicies un proceso sano).

Reinicia tras editar:  sudo systemctl restart allsafe-api
Prueba:
  curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/readyz
  sudo systemctl stop allsafe-db   # readyz debe pasar a 503, livez seguir 200
  sudo systemctl start allsafe-db

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 154 plantado."
