#!/usr/bin/env bash
# Lab 153: una app con la configuración y un secreto QUEMADOS en el código, y
# un servicio que arranca así. El alumno la hace 12-factor: toda la config por
# variables de entorno, el secreto fuera del código, misma imagen para dev/prod.
set -e
install -d -m 0755 /opt/allsafe

# App MALA de partida: config y secreto hardcodeados.
cat > /opt/allsafe/app.py <<'PY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

# MAL: configuración y secreto quemados en el código.
APP_ENV = "prod"
LOG_LEVEL = "DEBUG"
DB_HOST = "db-prod.allsafe.local"
SECRET_KEY = "s3cr3t-allsafe-prod-KEY"

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

# Servicio que arranca la app (sin EnvironmentFile todavía).
cat > /etc/systemd/system/allsafe-api.service <<'U'
[Unit]
Description=allsafe-api
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/allsafe/app.py
Restart=always

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now allsafe-api.service >/dev/null 2>&1 || true

install -d -m 0755 /etc/allsafe
chown -R analista:analista /opt/allsafe

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Configuración por ambiente (12-factor) para allsafe-api

/opt/allsafe/app.py tiene la configuración y un SECRETO quemados en el código.
Eso impide usar la misma imagen en dev y prod, y filtra el secreto en el repo.

1. Refactoriza app.py para que TODA la config venga del entorno:
   APP_ENV, LOG_LEVEL, DB_HOST y SECRET_KEY (usa os.environ).
   No debe quedar ningún valor de secreto escrito en el código.
2. Crea /etc/allsafe/app.env con esas variables (APP_ENV=prod) y permisos 600.
3. Haz que el servicio lea ese fichero:
   EnvironmentFile=/etc/allsafe/app.env  en allsafe-api.service.
4. Recarga y reinicia. Verifica:
   curl -s localhost:8080/           -> "env":"prod", "secret_set":true

Idea clave: misma app, solo cambian las variables. Cambiar app.env a
APP_ENV=dev y reiniciar bastaría para correr en dev, sin tocar el código.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 153 plantado."
