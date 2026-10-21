#!/usr/bin/env python3
"""'orders-app' de app-01. /health abre una conexión a db.interno:5432, espera
el saludo de minidb y hace PING. Devuelve 200 o 503 con el error de red tal
cual (igual que el log de una app real)."""
import ctypes
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = ("db.interno", 5432)
try:
    ctypes.CDLL(None).prctl(15, b"orders-app", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


def check_db():
    with socket.create_connection(DB, timeout=3) as s:
        f = s.makefile("rwb")
        banner = f.readline().strip().decode()
        f.write(b"PING\n")
        f.flush()
        if f.readline().strip() != b"PONG":
            raise RuntimeError("respuesta inesperada de la BD")
        return banner


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            code, body = 200, f"orders-app ok ({check_db()})\n"
        except Exception as e:  # noqa: BLE001
            code, body = 503, f"orders-app ERROR db {DB[0]}:{DB[1]}: {e}\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
