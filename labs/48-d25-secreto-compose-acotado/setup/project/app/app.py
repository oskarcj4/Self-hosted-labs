"""Stack de analítica. Según ROLE:
  upstream  API externa simulada (:9000); valida el token en la cabecera X-Token
  reporter  cada 5 s llama a upstream con el token de /run/secrets/api_token
  web       panel interno (:8080), no usa el token
  worker    tareas en segundo plano, no usa el token
"""
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROLE = os.environ.get("ROLE", "web")
EXPECTED = "rpt_tok_51c9e07a2b"


def serve(port, fn):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            code, text = fn(self)
            data = text.encode()
            self.send_response(code)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()


if ROLE == "upstream":
    serve(9000, lambda h: (200, "upstream ok\n") if h.headers.get("X-Token") == EXPECTED
          else (401, "token invalido\n"))
elif ROLE == "reporter":
    while True:
        try:
            with open("/run/secrets/api_token") as f:
                tok = f.read().strip()
            req = urllib.request.Request("http://upstream:9000/", headers={"X-Token": tok})
            status = "ok " + urllib.request.urlopen(req, timeout=3).read().decode().strip()
        except Exception as e:  # noqa: BLE001
            status = f"error {e}"
        with open("/tmp/status", "w") as f:
            f.write(f"{int(time.time())} {status}\n")
        time.sleep(5)
elif ROLE == "web":
    serve(8080, lambda h: (200, "panel interno ok\n"))
else:
    while True:
        time.sleep(30)
