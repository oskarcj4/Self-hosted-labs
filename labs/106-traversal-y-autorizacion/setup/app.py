#!/usr/bin/env python3
"""Visor de documentos (lab 106). Dos fallos controlados por config.json:
  - sanitize_path: si es false, /download no valida la ruta -> path traversal
    (se sale de /srv/docs y lee otros ficheros del servidor).
  - trust_admin_header: si es true, /admin se fía de la cabecera X-Admin que
    manda el cliente -> cualquiera se declara admin (broken access control).
El arreglo (blue) cierra las dos cosas sin romper la descarga legítima."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, unquote

APP = "/srv/app"
CFG = "/etc/panel/config.json"
DOCS = "/srv/docs"


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return {}


SEC = load(APP + "/secrets.json")

PUBLIC = b"""<!doctype html><meta charset=utf-8><title>docs.lab</title>
<h1>Visor de documentos - docs.lab</h1>
<p>Descarga: /download?file=readme.txt - Panel: /admin</p>"""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def out(self, code, body, ctype="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception:
            pass

    def do_GET(self):
        c = load(CFG)
        u = urlparse(self.path)
        path, q = u.path, parse_qs(u.query)

        if path in ("/", "/index.html"):
            return self.out(200, PUBLIC, "text/html; charset=utf-8")

        if path == "/download":
            name = unquote(q.get("file", [""])[0])
            if not name:
                return self.out(400, "falta ?file=")
            full = os.path.normpath(os.path.join(DOCS, name))
            if c.get("sanitize_path"):
                # Solo dentro de /srv/docs.
                if full != DOCS and not full.startswith(DOCS + os.sep):
                    return self.out(403, "ruta no permitida")
            try:
                with open(full, "rb") as f:
                    return self.out(200, f.read(8192))
            except Exception:
                return self.out(404, "no encontrado")

        if path == "/admin":
            hdr = self.headers.get("X-Admin", "").strip().lower()
            if c.get("trust_admin_header") and hdr in ("1", "true", "yes"):
                return self.out(200, "== panel admin ==\n"
                                + SEC.get("root_flag", "") + "\n")
            return self.out(403, "403 solo administradores")

        return self.out(404, "404")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
