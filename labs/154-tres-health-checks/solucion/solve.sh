#!/usr/bin/env bash
# Solución automática (corre como analista; sudo donde haga falta).
set -e

cat > /opt/allsafe/app.py <<'PY'
import json, socket, threading, time
from http.server import BaseHTTPRequestHandler, HTTPServer

STARTED = False
def _warmup():
    global STARTED
    time.sleep(2)          # simula carga de caché/conexiones al arrancar
    STARTED = True
threading.Thread(target=_warmup, daemon=True).start()

def db_ok():
    try:
        with socket.create_connection(("127.0.0.1", 5432), timeout=0.5):
            return True
    except OSError:
        return False

class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(data))); self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path == "/livez":
            # Liveness: ¿el proceso está vivo? No mira dependencias.
            self._send(200, {"live": True})
        elif self.path == "/startup":
            # Startup: ¿terminó el arranque?
            self._send(200 if STARTED else 503, {"started": STARTED})
        elif self.path == "/readyz":
            # Readiness: listo solo si arrancó Y la dependencia responde.
            ready = STARTED and db_ok()
            self._send(200 if ready else 503,
                       {"ready": ready, "started": STARTED, "db": db_ok()})
        else:
            self._send(200, {"app": "allsafe-api"})
    def log_message(self,*a): pass

HTTPServer(("127.0.0.1",8080), H).serve_forever()
PY

sudo systemctl restart allsafe-api
sleep 3   # deja pasar el warmup
echo -n "livez="; curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/livez
echo -n "readyz="; curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/readyz
echo "solve.sh completado."
