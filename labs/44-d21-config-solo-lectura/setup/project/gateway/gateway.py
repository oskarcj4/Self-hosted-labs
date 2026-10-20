"""API gateway: lee sus rutas de /etc/gateway/routes.conf y guarda una caché
de arranque. La caché va a GATEWAY_CACHE_DIR si está definida; si no, junto a
la configuración (/etc/gateway/.runtime-cache)."""
import hashlib
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONF = "/etc/gateway/routes.conf"
CACHE_DIR = os.environ.get("GATEWAY_CACHE_DIR", "/etc/gateway")

routes = {}
with open(CONF) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#"):
            path, upstream = line.split()
            routes[path] = upstream

# Si no puede escribir la caché, el gateway no arranca (fallo en el arranque).
os.makedirs(CACHE_DIR, exist_ok=True)
with open(os.path.join(CACHE_DIR, ".runtime-cache"), "w") as f:
    f.write(f"{time.time()} {hashlib.sha256(str(routes).encode()).hexdigest()}\n")


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body = f"gateway ok: {len(routes)} rutas, cache en {CACHE_DIR}\n"
        else:
            up = next((u for p, u in routes.items() if self.path.startswith(p)), None)
            body = f"-> {up}\n" if up else "sin ruta\n"
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
