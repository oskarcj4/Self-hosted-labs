#!/usr/bin/env python3
"""ingest: recibe lotes y los reenvía a la API de analítica con un token.
Busca el token, por orden:
  1. $CREDENTIALS_DIRECTORY/ingest_token   (LoadCredential= de systemd)
  2. el fichero indicado en INGEST_TOKEN_FILE
  3. la variable de entorno INGEST_API_TOKEN (obsoleta)
"""
import ctypes
import hashlib
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    ctypes.CDLL(None).prctl(15, b"ingest", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


def load_token():
    cred = os.environ.get("CREDENTIALS_DIRECTORY")
    if cred and os.path.exists(os.path.join(cred, "ingest_token")):
        path, src = os.path.join(cred, "ingest_token"), "credential"
    elif os.environ.get("INGEST_TOKEN_FILE"):
        path, src = os.environ["INGEST_TOKEN_FILE"], "file"
    else:
        return os.environ.get("INGEST_API_TOKEN", "").strip(), "env"
    try:
        with open(path) as f:
            return f.read().strip(), src
    except OSError as e:
        return "", f"{src} ilegible ({e.strerror})"


TOKEN, SOURCE = load_token()
OK_HASH = "1d2b7f6f0e5c4b3a"  # se sustituye al plantar


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        good = hashlib.sha256(TOKEN.encode()).hexdigest()[:16] == OK_HASH
        if good:
            code, body = 200, f"ingest ok: token valido (origen: {SOURCE})\n"
        else:
            code, body = 500, f"ingest ERROR: token invalido o ausente (origen: {SOURCE})\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8700), H).serve_forever()
