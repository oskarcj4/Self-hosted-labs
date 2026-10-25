#!/usr/bin/env python3
"""Importador de perfiles XML de SogetiCorp.

Recibe un <user><name>...</name></user> por POST /import y saluda al usuario.
El parser se montó con las entidades externas activadas ("por si algún día
importamos desde una URL"). Eso abre XXE.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from lxml import etree

HELP = ("POST /import  con  <user><name>ana</name></user>\n")


def parse_profile(xml_bytes):
    # --- VULNERABLE: carga DTD y resuelve entidades externas ---
    parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
    root = etree.fromstring(xml_bytes, parser)
    return root.findtext("name")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, code, body):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if urlparse(self.path).path == "/":
            return self._send(200, HELP)
        self._send(404, "no\n")

    def do_POST(self):
        if urlparse(self.path).path != "/import":
            return self._send(404, "no\n")
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        try:
            name = parse_profile(body)
        except Exception as e:
            return self._send(400, "xml invalido: %s\n" % e)
        self._send(200, "hola %s\n" % (name or ""))


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), H).serve_forever()
