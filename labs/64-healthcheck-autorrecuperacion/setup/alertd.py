#!/usr/bin/env python3
"""Receptor de alertas (stand-in de Slack/PagerDuty/Alertmanager) en
127.0.0.1:9000. Cada POST se apunta en /var/log/alerts/alerts.log."""
import ctypes
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = "/var/log/alerts/alerts.log"
try:
    ctypes.CDLL(None).prctl(15, b"alertd", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def _reply(self, code, body):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        msg = self.rfile.read(min(n, 4096)).decode(errors="replace").replace("\n", " ").strip()
        with open(LOG, "a") as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {self.path} {msg}\n")
        self._reply(202, "alerta recibida\n")

    def do_GET(self):
        self._reply(200, "alertd: envía un POST con el texto de la alerta, p.ej.\n"
                         "  curl -s -X POST --data 'catalog reiniciado' http://127.0.0.1:9000/alert\n")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 9000), H).serve_forever()
