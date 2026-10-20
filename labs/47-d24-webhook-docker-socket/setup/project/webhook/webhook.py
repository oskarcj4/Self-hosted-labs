"""Receptor de webhooks de despliegue.
  POST /hook          registra el evento en /events/events.log
  GET  /health
Si encuentra /var/run/docker.sock, además expone GET /debug/containers
(una función de diagnóstico que nadie usa)."""
import http.client
import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SOCK = "/var/run/docker.sock"


class UnixHTTP(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(SOCK)


class H(BaseHTTPRequestHandler):
    def reply(self, code, text):
        data = text.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/debug/containers" and os.path.exists(SOCK):
            c = UnixHTTP("docker")
            c.request("GET", "/containers/json?all=1")
            names = [x["Names"][0] for x in json.loads(c.getresponse().read())]
            return self.reply(200, "\n".join(names) + "\n")
        self.reply(200, "webhook ok\n")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode(errors="replace")
        with open("/events/events.log", "a") as f:
            f.write(f"{time.strftime('%FT%T')} {self.path} {body.strip()}\n")
        self.reply(202, "evento registrado\n")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 8090), H).serve_forever()
