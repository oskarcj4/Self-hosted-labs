#!/usr/bin/env python3
"""'shop' en 127.0.0.1:8500. Se lanza desde /srv/shop/current (la release
activa). Cada release trae su VERSION; la r43 además importa un módulo nuevo."""
import ctypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = open(os.path.join(HERE, "VERSION")).read().strip()
SCHEMA_DB = 13  # versión del esquema de la BD de producción
SCHEMA_MIN = {"r41": 11, "r42": 13, "r43": 13}
SCHEMA_MAX = {"r41": 12, "r42": 13, "r43": 13}

if VERSION == "r43":
    from pricing import calcular_total  # noqa: F401  (módulo nuevo de la r43)

try:
    ctypes.CDLL(None).prctl(15, b"shop", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        code, body = 200, f"shop {VERSION}\n"
        if self.path.startswith("/health"):
            if SCHEMA_MIN[VERSION] <= SCHEMA_DB <= SCHEMA_MAX[VERSION]:
                body = f"ok {VERSION} esquema={SCHEMA_DB}\n"
            else:
                code = 500
                body = (f"ERROR {VERSION}: la BD tiene el esquema {SCHEMA_DB} y esta release "
                        f"sólo entiende {SCHEMA_MIN[VERSION]}-{SCHEMA_MAX[VERSION]}\n")
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8500), H).serve_forever()
