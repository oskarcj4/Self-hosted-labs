"""Servicio genérico del stack 'handoff'. El rol sale de ROLE:
  web    -> HTTP :8080, pregunta a api
  api    -> HTTP :9000, escribe en el volumen compartido
  worker -> procesa lo que deja api en el volumen compartido
  db     -> TCP :5432 (base de datos simulada)
"""
import os
import socket
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "web")
SHARED = "/srv/reports"


def http(port, handler):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            body = handler(self.path).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()


if ROLE == "web":
    def web(path):
        try:
            api = urllib.request.urlopen("http://api:9000/", timeout=2).read().decode()
        except Exception as e:  # noqa: BLE001
            api = f"api no disponible: {e}\n"
        return "handoff web ok\n" + api
    http(8080, web)

elif ROLE == "api":
    def api(path):
        os.makedirs(SHARED, exist_ok=True)
        with open(f"{SHARED}/queue.txt", "a") as f:
            f.write(f"job {time.time()}\n")
        return "api ok\n"
    http(9000, api)

elif ROLE == "worker":
    while True:
        os.makedirs(SHARED, exist_ok=True)
        q = f"{SHARED}/queue.txt"
        n = sum(1 for _ in open(q)) if os.path.exists(q) else 0
        with open(f"{SHARED}/processed.txt", "w") as f:
            f.write(f"{n} jobs procesados {time.ctime()}\n")
        time.sleep(5)

elif ROLE == "db":
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", 5432))
    s.listen()
    while True:
        c, _ = s.accept()
        threading.Thread(target=lambda c=c: (c.sendall(b"db ok\n"), c.close())).start()
