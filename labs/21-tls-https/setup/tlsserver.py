#!/usr/bin/env python3
"""Servidor HTTPS del Lab 21. Lee el certificado y la clave de /etc/tls y sirve
en el puerto 8443. Si faltan el certificado o la clave, avisa y termina."""
import os
import ssl
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CRT = "/etc/tls/server.crt"
KEY = "/etc/tls/server.key"


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"https ok\n")


if __name__ == "__main__":
    if not (os.path.isfile(CRT) and os.path.isfile(KEY)):
        print(f"Faltan {CRT} y/o {KEY}. Genéralos con openssl primero.",
              file=sys.stderr)
        sys.exit(1)
    httpd = ThreadingHTTPServer(("0.0.0.0", 8443), H)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(CRT, KEY)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    print("Servidor HTTPS en https://0.0.0.0:8443")
    httpd.serve_forever()
