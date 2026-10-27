#!/usr/bin/env python3
"""Panel de borde (lab 103). Dos fallos controlados por config.json:
  - serve_backup: expone /backup/ (listado + .bak con el token de usuario)
  - debug:        /admin entrega la bandera root sin token
El punto del lab no es el panel, sino cerrar estas dos vias (modo blue)."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

APP = "/srv/app"
CFG = "/etc/panel/config.json"


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return {}


SEC = load(APP + "/secrets.json")   # tokens + banderas (root 600 / svc)

PUBLIC = b"""<!doctype html><meta charset=utf-8><title>gateway.lab</title>
<h1>Panel de estado - gateway.lab</h1>
<p>Servicio publico. Estado: OK.</p>"""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, body, ctype="text/html; charset=utf-8"):
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
        c = load(CFG)                           # releido en cada peticion
        u = urlparse(self.path)
        path, q = u.path, parse_qs(u.query)
        if path in ("/", "/index.html"):
            return self.send(200, PUBLIC)
        if path == "/backup/":
            if c.get("serve_backup"):
                return self.send(200, '<h1>Index of /backup/</h1><ul>'
                    '<li><a href="app.py.bak">app.py.bak</a></li>'
                    '<li><a href="notes.txt">notes.txt</a></li></ul>')
            return self.send(404, "404")
        if path == "/backup/app.py.bak":
            if c.get("serve_backup"):
                src = ("# volcado de build - NO SUBIR A PRODUCCION\n"
                       'USER_TOKEN = "%s"\n'
                       "# /area?token=USER_TOKEN   -> bandera de usuario\n"
                       "# /admin?token=ADMIN_TOKEN -> bandera root\n"
                       % SEC.get("user_token", ""))
                return self.send(200, src, "text/plain; charset=utf-8")
            return self.send(404, "404")
        if path == "/backup/notes.txt":
            if c.get("serve_backup"):
                return self.send(200, "TODO: sacar el backup del webroot.\n"
                                      "endpoints: /area?token= , /admin?token=\n",
                                 "text/plain; charset=utf-8")
            return self.send(404, "404")
        if path == "/area":
            if q.get("token", [""])[0] == SEC.get("user_token"):
                return self.send(200, "== area de usuario ==\n"
                                 + SEC.get("user_flag", "") + "\n",
                                 "text/plain; charset=utf-8")
            return self.send(403, "403 token invalido")
        if path == "/admin":
            tok = q.get("token", [""])[0]
            if c.get("debug") or tok == SEC.get("admin_token"):
                return self.send(200, "== consola admin ==\n"
                                 + SEC.get("root_flag", "") + "\n",
                                 "text/plain; charset=utf-8")
            return self.send(403, "403 no autorizado")
        return self.send(404, "404")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
