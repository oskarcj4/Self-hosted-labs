#!/usr/bin/env python3
"""ops-admin: panel de administración interno. Lee BIND_ADDR y PORT de
/etc/ops-admin/admin.conf (formato CLAVE=valor)."""
import ctypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

conf = {"BIND_ADDR": "127.0.0.1", "PORT": "9090"}
with open("/etc/ops-admin/admin.conf") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            conf[k.strip()] = v.strip().strip('"')

try:
    ctypes.CDLL(None).prctl(15, b"ops-admin", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (b"ops-admin panel\n"
                b"[usuarios] [reiniciar servicios] [borrar caches] [exportar BD]\n")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer((conf["BIND_ADDR"], int(conf["PORT"])), H).serve_forever()
