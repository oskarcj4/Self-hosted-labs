#!/usr/bin/env python3
"""'gestion': app detrás de nginx. Escucha en 127.0.0.1:$PORT (de
/etc/gestion/gestion.env). /api/informe tarda 12 s a propósito: es un informe
pesado que genera la app en cada petición."""
import ctypes
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    ctypes.CDLL(None).prctl(15, b"gestion", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass
PORT = int(os.environ.get("PORT", "8000"))


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/informe"):
            time.sleep(12)
            body = b"informe listo: 1834 lineas\n"
        else:
            body = b"gestion ok\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
