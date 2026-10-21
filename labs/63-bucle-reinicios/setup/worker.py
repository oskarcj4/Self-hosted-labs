#!/usr/bin/env python3
"""'payments-worker': necesita PAYMENTS_API_URL y escucha /health en
127.0.0.1:9090. Si le falta algo, sale con error (y systemd lo reinicia)."""
import ctypes
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    ctypes.CDLL(None).prctl(15, b"payments-worker", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass
url = os.environ.get("PAYMENTS_API_URL")
if not url:
    print("FATAL: falta la variable PAYMENTS_API_URL", file=sys.stderr, flush=True)
    sys.exit(78)
print(f"payments-worker arrancando, API={url}", flush=True)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"payments-worker ok\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


try:
    srv = ThreadingHTTPServer(("127.0.0.1", 9090), H)
except OSError as e:
    print(f"FATAL: no puedo escuchar en 127.0.0.1:9090: {e}", file=sys.stderr, flush=True)
    sys.exit(1)
srv.serve_forever()
