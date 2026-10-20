"""Inventario: ROLE=db es una base de datos simulada (TCP :5432, responde
PONG a PING); ROLE=app es la API (:8000) que consulta a la base de datos."""
import os
import socket
import socketserver
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "app")

if ROLE == "db":
    class DB(socketserver.StreamRequestHandler):
        def handle(self):
            for line in self.rfile:
                cmd = line.decode(errors="replace").strip().upper()
                if cmd == "PING":
                    self.wfile.write(b"PONG\n")
                elif cmd == "DUMP":
                    self.wfile.write(b"sku,stock,coste\nA-100,42,3.10\nB-220,7,18.90\n")
                else:
                    self.wfile.write(b"ERR\n")
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    socketserver.ThreadingTCPServer(("0.0.0.0", 5432), DB).serve_forever()
else:
    def db_ping():
        try:
            with socket.create_connection((os.environ.get("DB_HOST", "db"), 5432), timeout=2) as s:
                s.sendall(b"PING\n")
                return s.recv(64).decode().strip()
        except OSError as e:
            return f"ERROR {e}"

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            r = db_ping()
            body = f"inventario api — db: {r}\n".encode()
            self.send_response(200 if r == "PONG" else 503)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
