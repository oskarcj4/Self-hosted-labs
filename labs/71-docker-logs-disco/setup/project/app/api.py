"""API de pedidos (lab 71): responde en :8000 y escribe una línea de log por petición."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"servicio": "pedidos-api", "estado": "ok"}).encode() + b"\n"
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
