#!/usr/bin/env python3
"""NetBox mini: herramienta de red del panel de operaciones.

Resuelve un host con `getent hosts`. El equipo lo montó con shell=True para
"que fuera rápido". El parámetro host entra tal cual en la línea de comandos.
"""
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PAGE = b"""<!doctype html><meta charset=utf-8><title>NetBox</title>
<h2>Resolver host</h2>
<form method=get action=/run>
  host: <input name=host value=localhost><button>resolver</button>
</form>"""


def lookup(host):
    # --- VULNERABLE: host va a una shell sin validar ---
    cmd = "getent hosts " + host
    out = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/":
            return self._send(200, PAGE)
        if u.path == "/run":
            host = parse_qs(u.query).get("host", [""])[0]
            if not host:
                return self._send(400, "falta host\n")
            return self._send(200, lookup(host))
        self._send(404, "no\n")


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), H).serve_forever()
