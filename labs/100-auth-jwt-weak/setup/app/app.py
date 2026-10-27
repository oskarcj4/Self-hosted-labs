#!/usr/bin/env python3
"""API de SogetiCorp con sesiones por JWT (HS256, firmado a mano).

El login entrega un token con el rol del usuario. /admin solo debería servir
a quien tenga rol admin. El verificador, sin embargo, se fía del campo "alg"
del propio token: ese es el fallo.
"""
import base64
import hashlib
import hmac
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

ENV = {}
for _l in open("/srv/app/.env"):
    k, _, v = _l.strip().partition("=")
    if k:
        ENV[k] = v
FLAG = ENV["FLAG"]
SECRET = ENV["JWT_SECRET"].encode()

USERS = {"ana": "Primavera2024", "luis": "Verano.2024"}  # todos rol "user"


def b64u(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def b64u_dec(txt):
    txt += "=" * (-len(txt) % 4)
    return base64.urlsafe_b64decode(txt)


def issue(payload):
    header = {"alg": "HS256", "typ": "JWT"}
    seg = b64u(json.dumps(header).encode()) + b"." + b64u(json.dumps(payload).encode())
    sig = b64u(hmac.new(SECRET, seg, hashlib.sha256).digest())
    return (seg + b"." + sig).decode()


def verify(token):
    try:
        h_b, p_b, s_b = token.split(".")
        header = json.loads(b64u_dec(h_b))
        payload = json.loads(b64u_dec(p_b))
    except Exception:
        return None
    alg = header.get("alg")
    # --- VULNERABLE: si el token dice "none", se acepta sin firma ---
    if alg == "none":
        return payload
    expected = b64u(hmac.new(SECRET, (h_b + "." + p_b).encode(), hashlib.sha256).digest()).decode()
    if hmac.compare_digest(expected, s_b):
        return payload
    return None


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, code, body):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _token(self):
        a = self.headers.get("Authorization", "")
        return a[7:] if a.startswith("Bearer ") else ""

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            return self._send(200, "API. POST /login ; GET /me ; GET /admin (Bearer token)\n")
        payload = verify(self._token())
        if path == "/me":
            if not payload:
                return self._send(401, "token invalido\n")
            return self._send(200, "user=%s role=%s\n" % (payload.get("user"), payload.get("role")))
        if path == "/admin":
            if not payload:
                return self._send(401, "token invalido\n")
            if payload.get("role") != "admin":
                return self._send(403, "solo admin\n")
            return self._send(200, "panel admin\nflag=%s\n" % FLAG)
        self._send(404, "no\n")

    def do_POST(self):
        if urlparse(self.path).path != "/login":
            return self._send(404, "no\n")
        n = int(self.headers.get("Content-Length", 0))
        data = parse_qs(self.rfile.read(n).decode(errors="replace"))
        user = data.get("user", [""])[0]
        password = data.get("password", [""])[0]
        if USERS.get(user) != password:
            return self._send(401, "credenciales invalidas\n")
        return self._send(200, "token=%s\n" % issue({"user": user, "role": "user"}))


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), H).serve_forever()
