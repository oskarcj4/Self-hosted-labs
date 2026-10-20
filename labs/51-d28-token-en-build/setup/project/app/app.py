"""Notificaciones. Según ROLE:
  gateway   pasarela de envío simulada (:9000); valida el token Bearer
  notifier  cada 4 s envía una notificación de prueba a la pasarela
Token del notifier, por orden: fichero NOTIFY_TOKEN_FILE, /app/.token, variable NOTIFY_TOKEN."""
import hashlib
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "notifier")
TOKEN_SHA = "0d8f2b0c4f4bdc7c0b6a8e1d2f3c4b5a6e7f8091a2b3c4d5e6f708192a3b4c5d"  # se fija al plantar


def token():
    path = os.environ.get("NOTIFY_TOKEN_FILE")
    if path:
        with open(path) as f:
            return f.read().strip(), "file"
    if os.path.exists("/app/.token"):
        with open("/app/.token") as f:
            return f.read().strip(), "image"
    return os.environ.get("NOTIFY_TOKEN", ""), "env"


if ROLE == "gateway":
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            tok = self.headers.get("Authorization", "").removeprefix("Bearer ")
            good = hashlib.sha256(tok.encode()).hexdigest() == TOKEN_SHA
            data = b"gateway ok\n" if good else b"no autorizado\n"
            self.send_response(200 if good else 401)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", 9000), H).serve_forever()
else:
    while True:
        try:
            tok, src = token()
            req = urllib.request.Request("http://gateway:9000/", headers={"Authorization": f"Bearer {tok}"})
            st = f"ok ({src}) " + urllib.request.urlopen(req, timeout=3).read().decode().strip()
        except Exception as e:  # noqa: BLE001
            st = f"error {e}"
        with open("/tmp/status", "w") as f:
            f.write(f"{int(time.time())} {st}\n")
        time.sleep(4)
