#!/usr/bin/env python3
"""notifier: envía avisos por SMTP y webhook. Toma sus secretos del entorno
(SMTP_PASSWORD, WEBHOOK_TOKEN) que systemd carga desde un EnvironmentFile."""
import ctypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    ctypes.CDLL(None).prctl(15, b"notifier", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        smtp = bool(os.environ.get("SMTP_PASSWORD"))
        hook = bool(os.environ.get("WEBHOOK_TOKEN"))
        if smtp and hook:
            code, body = 200, "notifier ok: smtp configured, webhook configured\n"
        else:
            code, body = 500, f"notifier ERROR: smtp={smtp} webhook={hook} (faltan secretos)\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8500), H).serve_forever()
