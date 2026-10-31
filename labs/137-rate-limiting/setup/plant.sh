#!/usr/bin/env bash
# Lab 137: /api/login sin límite de peticiones y un bot probando contraseñas.
set -e
mkdir -p /opt/login /var/www/web/static
echo 'console.log("app");' > /var/www/web/static/app.js
echo '<h1>Web 137</h1>' > /var/www/web/index.html
cat > /opt/login/app.py <<'PY'
import json, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def _r(self):
        time.sleep(0.02)                 # comprobar la contraseña cuesta CPU
        b = json.dumps({"error": "credenciales incorrectas"}).encode()
        self.send_response(401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        self._r()
    do_GET = _r
    def log_message(self, *a):
        pass
ThreadingHTTPServer(("127.0.0.1", 9137), H).serve_forever()
PY
cat > /etc/systemd/system/login-api.service <<'U'
[Unit]
Description=API de login
[Service]
ExecStart=/usr/bin/python3 /opt/login/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /etc/nginx/sites-available/web <<'N'
server {
    listen 80 default_server;
    root /var/www/web;

    location / {
        try_files $uri $uri/ =404;
    }

    location /api/login {
        proxy_pass http://127.0.0.1:9137;
    }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/web /etc/nginx/sites-enabled/web
systemctl daemon-reload
systemctl enable --now login-api nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-137.txt <<'TXT'
SEC-137 · web-137
El login recibe miles de intentos por minuto y la API va lenta para todos.
1. Identifica en el access.log la IP que más pide /api/login -> ~/limite.txt: ip_bot=<IP>
2. Mide con hey ANTES de tocar nada:   hey ... > ~/hey-antes.txt
3. Limita /api/login por IP (peticiones/s con ráfaga + conexiones simultáneas),
   que responda 429 al pasarse. Los estáticos (/static/) sin límite.
4. Vuelve a medir:                     hey ... > ~/hey-despues.txt
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 137 plantado."
