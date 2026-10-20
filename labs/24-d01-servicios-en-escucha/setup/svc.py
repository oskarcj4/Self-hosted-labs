#!/usr/bin/env python3
"""Servicio HTTP mínimo del escenario: svc.py NOMBRE HOST PUERTO.
Cambia su nombre de proceso a NOMBRE para que `ss -tlnp` / `ps` lo muestren
como un servicio real (y no como 'python3')."""
import ctypes
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

name, host, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:  # PR_SET_NAME = 15 (máx. 15 caracteres)
    ctypes.CDLL(None).prctl(15, name.encode()[:15], 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"{name} ok\n".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer((host, port), H).serve_forever()
