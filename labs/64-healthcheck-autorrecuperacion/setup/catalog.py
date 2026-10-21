#!/usr/bin/env python3
"""'catalog' en 127.0.0.1:8300. Simula el fallo real que sufre en producción:
de vez en cuando se queda bloqueado (un deadlock en su pool). El proceso sigue
vivo y systemd lo ve 'active', pero ninguna petición recibe respuesta.
En el lab, el bloqueo se provoca con el fichero /run/catalog/hang."""
import ctypes
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HANG = "/run/catalog/hang"
try:
    ctypes.CDLL(None).prctl(15, b"catalog", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass
try:
    os.unlink(HANG)
except FileNotFoundError:
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        while os.path.exists(HANG):
            time.sleep(1)
        body = b"catalog ok\n" if self.path.startswith("/health") else b"[{\"sku\":\"A-100\"}]\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8300), H).serve_forever()
