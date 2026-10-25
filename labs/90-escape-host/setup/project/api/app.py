#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

MSG = Path("/data/msg")


class H(BaseHTTPRequestHandler):
    def log_message(self, *_a):
        pass

    def do_GET(self):
        try:
            body = MSG.read_bytes()
        except OSError:
            body = b"missing-data\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), H).serve_forever()
