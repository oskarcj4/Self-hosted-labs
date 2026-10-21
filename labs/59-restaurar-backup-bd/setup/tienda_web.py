#!/usr/bin/env python3
"""'tienda-web': /health consulta clientes y pedidos con psql (por socket, como
el usuario de sistema 'tienda'). 200 si ambas tablas responden, 500 con el
error de PostgreSQL si no."""
import ctypes
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    ctypes.CDLL(None).prctl(15, b"tienda-web", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass
SQL = ("select (select count(*) from clientes) || ' clientes, ' || "
       "(select count(*) from pedidos) || ' pedidos'")


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        p = subprocess.run(["psql", "-d", "tienda", "-tAc", SQL],
                           capture_output=True, text=True, timeout=5)
        if p.returncode == 0:
            code, body = 200, f"tienda-web ok: {p.stdout.strip()}\n"
        else:
            code, body = 500, f"tienda-web ERROR: {p.stderr.strip()}\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
