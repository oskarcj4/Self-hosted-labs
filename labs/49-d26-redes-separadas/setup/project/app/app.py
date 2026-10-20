"""Tienda en tres capas. Según ROLE:
  web  (:8080) pública; pide los datos a api
  api  (:9000) consulta a db
  db   (:5432) base de datos simulada (PING -> PONG)
"""
import os
import socket
import socketserver
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "web")


def serve(port, fn):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            text = fn()
            data = text.encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()


def web():
    try:
        return "web ok -> " + urllib.request.urlopen("http://api:9000/", timeout=3).read().decode()
    except Exception as e:  # noqa: BLE001
        return f"web ok -> api ERROR {e}\n"


def api():
    try:
        with socket.create_connection(("db", 5432), timeout=2) as s:
            s.sendall(b"PING\n")
            return f"api ok -> db {s.recv(16).decode().strip()}\n"
    except OSError as e:
        return f"api ok -> db ERROR {e}\n"


if ROLE == "db":
    class DB(socketserver.StreamRequestHandler):
        def handle(self):
            for line in self.rfile:
                self.wfile.write(b"PONG\n" if line.strip() == b"PING" else b"ERR\n")
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    socketserver.ThreadingTCPServer(("0.0.0.0", 5432), DB).serve_forever()
elif ROLE == "api":
    serve(9000, api)
else:
    serve(8080, web)
