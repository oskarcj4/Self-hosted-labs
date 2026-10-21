#!/usr/bin/env python3
"""Backend del lab 69 en :8080. MODE=ok responde al momento; MODE=503 devuelve
503 (sin conexión a su BD); MODE=slow tarda 8 s (GC atascado).
/__lab/break y /__lab/heal cambian entre el modo averiado y 'ok' (los usa el
validador para simular la avería y la recuperación)."""
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NAME = os.environ.get("NAME", "app")
BROKEN = os.environ.get("MODE", "ok")
state = {"mode": BROKEN}


class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = body.encode()
        self.send_response(code)
        self.send_header("X-Backend", NAME)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/__lab/break":
            state["mode"] = BROKEN
            return self._send(200, f"{NAME} -> {BROKEN}\n")
        if self.path == "/__lab/heal":
            state["mode"] = "ok"
            return self._send(200, f"{NAME} -> ok\n")
        if state["mode"] == "503":
            return self._send(503, f"{NAME}: sin conexión con la base de datos\n")
        if state["mode"] == "slow":
            time.sleep(8)
        self._send(200, f"{NAME} ok\n")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
