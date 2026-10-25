#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
VERSION = open(os.path.join(ROOT, "VERSION"), encoding="utf-8").read().strip()
NAME = os.environ.get("SHOP_NAME", "app")
PORT = int(os.environ.get("PORT", "8080"))


class H(BaseHTTPRequestHandler):
    def log_message(self, *_a):
        pass

    def _send(self, code, body):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("X-Shop-Name", NAME)
        self.send_header("X-Shop-Version", VERSION)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/health", "/"):
            self._send(200, f"ok {VERSION} {NAME}\n")
        elif path == "/version":
            self._send(200, f"{VERSION} {NAME}\n")
        elif path == "/vuln":
            if VERSION.startswith("1.0"):
                self._send(200, "CVE-2024-SHOP open\n")
            else:
                self._send(404, "gone\n")
        else:
            self._send(404, "not found\n")


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
