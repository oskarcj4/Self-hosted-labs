"""uploader: sube ficheros a un almacenamiento externo (upstream simulado).
Token: si existe UPLOADER_API_TOKEN_FILE lo lee de ese fichero; si no, de la
variable UPLOADER_API_TOKEN (obsoleto)."""
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "uploader")
EXPECTED = "upl_live_7d3e91c4a0f2"


def token():
    path = os.environ.get("UPLOADER_API_TOKEN_FILE")
    if path:
        with open(path) as f:
            return f.read().strip(), "file"
    return os.environ.get("UPLOADER_API_TOKEN", ""), "env"


if ROLE == "storage":
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            good = self.headers.get("Authorization") == f"Bearer {EXPECTED}"
            data = b"storage ok\n" if good else b"no autorizado\n"
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
            req = urllib.request.Request("http://storage:9000/", headers={"Authorization": f"Bearer {tok}"})
            st = f"ok ({src}) " + urllib.request.urlopen(req, timeout=3).read().decode().strip()
        except Exception as e:  # noqa: BLE001
            st = f"error {e}"
        with open("/tmp/status", "w") as f:
            f.write(f"{int(time.time())} {st}\n")
        time.sleep(4)
