#!/usr/bin/env python3
"""'checkout' de app-03. /health llama a http://pagos:8080/health (nombre
corto, como en muchas configs reales) y devuelve el error tal cual."""
import ctypes
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

URL = "http://pagos:8080/health"
try:
    ctypes.CDLL(None).prctl(15, b"checkout", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with urllib.request.urlopen(URL, timeout=4) as r:
                code, body = 200, f"checkout ok -> {r.read().decode().strip()}\n"
        except Exception as e:  # noqa: BLE001
            code, body = 503, f"checkout ERROR llamando a {URL}: {e}\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
