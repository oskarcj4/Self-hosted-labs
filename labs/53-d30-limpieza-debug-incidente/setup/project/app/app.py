"""Portal de clientes (:8000). /admin exige la cabecera X-Admin-Key, salvo
que AUTH_BYPASS=true (modo de depuración)."""
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BYPASS = os.environ.get("AUTH_BYPASS", "").lower() == "true"
ADMIN_KEY = os.environ.get("ADMIN_KEY", "")


class H(BaseHTTPRequestHandler):
    def reply(self, code, text):
        data = text.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/admin"):
            if BYPASS or (ADMIN_KEY and self.headers.get("X-Admin-Key") == ADMIN_KEY):
                return self.reply(200, "panel de administración: 1.204 clientes\n")
            return self.reply(401, "no autorizado\n")
        self.reply(200, "Portal de clientes\n")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
