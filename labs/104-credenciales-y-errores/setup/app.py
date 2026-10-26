#!/usr/bin/env python3
"""Panel de borde (lab 104). Dos fallos controlados por config.json:
  - panel_pass: contraseña del panel admin (arranca con una por defecto débil)
  - verbose_errors: /debug devuelve la traza completa, que filtra la bandera
El punto del lab (modo blue) es endurecer la credencial y callar los errores,
sin romper el panel para quien tiene la contraseña buena."""
import base64
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


SEC = load(APP + "/secrets.json")   # banderas (root 600 / svc)

PUBLIC = b"""<!doctype html><meta charset=utf-8><title>gateway.lab</title>
<h1>Panel de estado - gateway.lab</h1>
<p>Servicio publico. Estado: OK. El panel admin esta en /panel.</p>"""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, body, ctype="text/plain; charset=utf-8", hdrs=None):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (hdrs or {}).items():
            self.send_header(k, v)
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception:
            pass

    def basic_user_pass(self):
        h = self.headers.get("Authorization", "")
        if not h.startswith("Basic "):
            return None, None
        try:
            raw = base64.b64decode(h[6:]).decode("utf-8", "replace")
            u, _, p = raw.partition(":")
            return u, p
        except Exception:
            return None, None

    def do_GET(self):
        c = load(CFG)
        u = urlparse(self.path)
        path, q = u.path, parse_qs(u.query)
        if path in ("/", "/index.html"):
            return self.send(200, PUBLIC, "text/html; charset=utf-8")

        if path == "/panel":
            user, pw = self.basic_user_pass()
            good = str(c.get("panel_pass", ""))
            if user == "admin" and pw == good and good != "":
                return self.send(200, "== panel admin ==\n"
                                 + SEC.get("user_flag", "") + "\n")
            return self.send(401, "401 autenticacion requerida",
                             hdrs={"WWW-Authenticate": 'Basic realm="panel"'})

        if path == "/debug":
            # Simula un error al procesar q. Con verbose_errors, el "traceback"
            # arrastra el contexto del proceso... incluida la bandera root.
            if c.get("verbose_errors"):
                tb = ("Traceback (most recent call last):\n"
                      '  File "/srv/app/app.py", line 999, in handle\n'
                      "    raise RuntimeError(ctx)\n"
                      "RuntimeError: contexto={'env': 'prod', "
                      "'ROOT_FLAG': '%s', 'q': %r}\n"
                      % (SEC.get("root_flag", ""), q.get("q", [""])[0]))
                return self.send(500, tb)
            return self.send(500, "500 Internal Server Error\n")

        return self.send(404, "404")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
