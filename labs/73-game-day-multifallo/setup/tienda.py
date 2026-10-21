#!/usr/bin/env python3
"""'tienda' en :8080. /health comprueba que puede guardar subidas en
/srv/app/uploads y consultar PostgreSQL en db.interno. Al cliente sólo le
dice "error interno"; el detalle va al journal (como en producción)."""
import ctypes
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UP = "/srv/app/uploads"
DSN = "host=db.interno port=5432 dbname=tienda user=tienda password=Tienda-2026 connect_timeout=3"
try:
    ctypes.CDLL(None).prctl(15, b"tienda", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


def health():
    with tempfile.NamedTemporaryFile(dir=UP, prefix=".health-") as f:
        f.write(b"x" * 262144)
        f.flush()
        os.fsync(f.fileno())
    r = subprocess.run(["psql", "-XAtq", DSN, "-c", "SELECT count(*) FROM productos"],
                       capture_output=True, text=True, timeout=8)
    if r.returncode != 0:
        raise RuntimeError("PostgreSQL: " + r.stderr.strip().replace("\n", " | "))
    return int(r.stdout.strip())


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            n = health()
            code, body = 200, f"tienda ok ({n} productos)\n"
        except Exception as e:  # noqa: BLE001
            print(f"ERROR /health: {e}", file=sys.stderr, flush=True)
            code, body = 503, "503 error interno\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
