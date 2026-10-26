#!/usr/bin/env python3
"""Proxy de estado (lab 105). /fetch trae una URL desde el servidor. Si no se
restringe el destino, se puede apuntar al servicio interno de metadatos
(127.0.0.1:8081), que no debería ser alcanzable desde fuera: eso es SSRF.
El arreglo (blue) es una allowlist de destinos, sin romper el health legítimo."""
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
from urllib.request import urlopen

APP = "/srv/app"
CFG = "/etc/panel/config.json"


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return {}


SEC = load(APP + "/secrets.json")

PUBLIC = b"""<!doctype html><meta charset=utf-8><title>status-proxy.lab</title>
<h1>Proxy de estado - status-proxy.lab</h1>
<p>Comprueba servicios: /fetch?url=http://status.lab:8080/health</p>"""


class Pub(BaseHTTPRequestHandler):
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
        if path == "/health":
            return self.out(200, "OK")
        if path == "/fetch":
            url = q.get("url", [""])[0]
            if not url:
                return self.out(400, "falta ?url=")
            if c.get("restrict_targets"):
                if url not in c.get("allowlist", []):
                    return self.out(403, "destino no permitido (allowlist)")
            try:
                with urlopen(url, timeout=3) as r:
                    return self.out(200, r.read(4096))
            except Exception as e:
                return self.out(502, "error al traer la URL: " + str(e)[:120])
        return self.out(404, "404")


class Meta(BaseHTTPRequestHandler):
    """Servicio interno de metadatos. Solo escucha en 127.0.0.1:8081."""
    def log_message(self, *a):
        pass

    def do_GET(self):
        path = urlparse(self.path).path
        body = {"/user": SEC.get("user_flag", ""),
                "/root": SEC.get("root_flag", "")}.get(path)
        if body is None:
            body = "metadata service - rutas: /user /root"
        b = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        try:
            self.wfile.write(b)
        except Exception:
            pass


if __name__ == "__main__":
    threading.Thread(
        target=ThreadingHTTPServer(("127.0.0.1", 8081), Meta).serve_forever,
        daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", 8080), Pub).serve_forever()
