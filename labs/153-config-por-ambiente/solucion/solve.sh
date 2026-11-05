#!/usr/bin/env bash
# Solución automática (corre como analista; usa sudo donde hace falta).
set -e

# 1) App 12-factor: toda la config del entorno, sin secreto quemado.
cat > /opt/allsafe/app.py <<'PY'
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer

APP_ENV   = os.environ.get("APP_ENV", "dev")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
DB_HOST   = os.environ.get("DB_HOST", "localhost")
SECRET_KEY = os.environ.get("SECRET_KEY", "")

class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path == "/healthz":
            self._send(200, {"status":"ok"})
        else:
            self._send(200, {"env":APP_ENV,"log_level":LOG_LEVEL,
                             "db_host":DB_HOST,"secret_set":bool(SECRET_KEY)})
    def log_message(self,*a): pass

if __name__ == "__main__":
    HTTPServer(("127.0.0.1",8080), H).serve_forever()
PY

# 2) EnvironmentFile con la config de prod, permisos 600.
sudo install -d -m 0755 /etc/allsafe
sudo tee /etc/allsafe/app.env >/dev/null <<'ENVF'
APP_ENV=prod
LOG_LEVEL=INFO
DB_HOST=db-prod.allsafe.local
SECRET_KEY=s3cr3t-allsafe-prod-KEY
ENVF
sudo chmod 600 /etc/allsafe/app.env

# 3) El servicio carga el EnvironmentFile.
sudo tee /etc/systemd/system/allsafe-api.service >/dev/null <<'U'
[Unit]
Description=allsafe-api
After=network.target

[Service]
EnvironmentFile=/etc/allsafe/app.env
ExecStart=/usr/bin/python3 /opt/allsafe/app.py
Restart=always

[Install]
WantedBy=multi-user.target
U

# 4) Recargar y reiniciar.
sudo systemctl daemon-reload
sudo systemctl restart allsafe-api.service
sleep 1
curl -s localhost:8080/ ; echo
echo "solve.sh completado."
