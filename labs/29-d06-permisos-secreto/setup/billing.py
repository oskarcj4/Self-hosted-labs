#!/usr/bin/env python3
"""billing-api: firma cada respuesta con la clave de /etc/billing/secret.key.
Lee la clave en cada petición: si pierde acceso al fichero, /health falla."""
import ctypes
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY = "/etc/billing/secret.key"
try:
    ctypes.CDLL(None).prctl(15, b"billing-api", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with open(KEY, "rb") as f:
                key = f.read().strip()
            sig = hmac.new(key, b"health", hashlib.sha256).hexdigest()[:12]
            code, body = 200, f"billing-api ok: secret loaded (sig {sig})\n"
        except OSError as e:
            code, body = 500, f"billing-api ERROR: no puedo leer {KEY}: {e.strerror}\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8200), H).serve_forever()
