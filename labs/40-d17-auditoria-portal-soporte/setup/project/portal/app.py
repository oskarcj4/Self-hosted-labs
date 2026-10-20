"""Portal de soporte (v2.3.1): formulario de tickets y subida de adjuntos."""
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPLOADS = "/app/uploads"


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        n = len(os.listdir(UPLOADS)) if os.path.isdir(UPLOADS) else 0
        body = f"Portal de soporte v2.3.1 — {n} adjuntos\n".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
