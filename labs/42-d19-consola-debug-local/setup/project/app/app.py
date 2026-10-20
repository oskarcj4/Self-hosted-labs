"""API de facturación: :8000 (pública) y consola de depuración en :5555,
que evalúa expresiones Python sin autenticación (sólo para soporte local)."""
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def serve(port, handler):
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            body = handler(self.path).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()


def console(path):
    q = parse_qs(urlparse(path).query).get("eval", [""])[0]
    if not q:
        return "debug-console v0.3 — uso: /?eval=<expresion python>\n"
    try:
        return f"{eval(q)}\n"  # noqa: S307  (precisamente el problema)
    except Exception as e:  # noqa: BLE001
        return f"error: {e}\n"


threading.Thread(target=serve, args=(5555, console), daemon=True).start()
serve(8000, lambda p: "billing-api ok\n")
