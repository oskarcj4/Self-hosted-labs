#!/usr/bin/env python3
"""Gateway de SogetiCorp. Expone 3 servicios en localhost:

  :8080  fetcher publico  -> /fetch?url=...   (lo usa el frontend)
  :8090  api.internal     -> /status          (servicio legitimo)
  :9000  metadata interno -> /flag            (NO debe salir al exterior)

El fetcher inyecta la cabecera X-Internal-Auth en cada peticion saliente, que
es como los servicios internos saben que la llamada viene del gateway. El
secreto solo lo conoce el proceso 'app' (esta en /srv/app/.env, no en el
codigo). El fetcher no valida la URL: ese es el fallo.
"""
import threading
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ENV = {}
for _l in open("/srv/app/.env"):
    k, _, v = _l.strip().partition("=")
    if k:
        ENV[k] = v
FLAG = ENV["FLAG"]
AUTH = ENV["INTERNAL_AUTH"]


def _reply(h, code, body, ctype="text/plain; charset=utf-8"):
    if isinstance(body, str):
        body = body.encode()
    h.send_response(code)
    h.send_header("Content-Type", ctype)
    h.send_header("Content-Length", str(len(body)))
    h.end_headers()
    h.wfile.write(body)


class Metadata(BaseHTTPRequestHandler):           # :9000 interno
    def log_message(self, *a): pass
    def do_GET(self):
        if self.headers.get("X-Internal-Auth") != AUTH:
            return _reply(self, 403, "forbidden: solo el gateway interno\n")
        if urlparse(self.path).path == "/flag":
            return _reply(self, 200, "flag=%s\n" % FLAG)
        _reply(self, 404, "no\n")


class InternalApi(BaseHTTPRequestHandler):         # :8090 api.internal
    def log_message(self, *a): pass
    def do_GET(self):
        if self.headers.get("X-Internal-Auth") != AUTH:
            return _reply(self, 403, "forbidden\n")
        if urlparse(self.path).path == "/status":
            return _reply(self, 200, "status: ok\nservice: api.internal\n")
        _reply(self, 404, "no\n")


def do_fetch(url):
    # --- VULNERABLE: se busca cualquier URL que pida el cliente ---
    req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
    with urllib.request.urlopen(req, timeout=4) as r:
        return r.read().decode(errors="replace")


class Fetcher(BaseHTTPRequestHandler):             # :8080 publico
    def log_message(self, *a): pass
    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/":
            return _reply(self, 200, "gateway: usa /fetch?url=http://api.internal:8090/status\n")
        if u.path == "/fetch":
            url = parse_qs(u.query).get("url", [""])[0]
            if not url:
                return _reply(self, 400, "falta url\n")
            try:
                return _reply(self, 200, do_fetch(url))
            except Exception as e:
                return _reply(self, 502, "fetch error: %s\n" % e)
        _reply(self, 404, "no\n")


def serve(port, handler):
    HTTPServer(("127.0.0.1", port), handler).serve_forever()


if __name__ == "__main__":
    threading.Thread(target=serve, args=(9000, Metadata), daemon=True).start()
    threading.Thread(target=serve, args=(8090, InternalApi), daemon=True).start()
    serve(8080, Fetcher)
