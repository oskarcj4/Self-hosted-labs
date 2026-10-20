#!/usr/bin/env python3
"""media-app: recibe subidas y las guarda en /var/www/media/uploads.
  POST /upload?name=foto.png[&dir=avatars]   (cuerpo = contenido)
  GET  /health
"""
import ctypes
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = "/var/www/media/uploads"
SAFE = re.compile(r"^[A-Za-z0-9._-]{1,64}$")
try:
    ctypes.CDLL(None).prctl(15, b"media-app", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def reply(self, code, text):
        data = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.reply(200, "media-app ok\n")

    def do_POST(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        name = q.get("name", [""])[0]
        sub = q.get("dir", [""])[0]
        if u.path != "/upload" or not SAFE.match(name) or (sub and not SAFE.match(sub)):
            return self.reply(400, "peticion invalida\n")
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        dest = os.path.join(ROOT, sub, name)
        try:
            with open(dest, "wb") as f:
                f.write(body)
        except OSError as e:
            return self.reply(500, f"no puedo escribir {dest}: {e.strerror}\n")
        self.reply(200, f"guardado {dest}\n")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8300), H).serve_forever()
