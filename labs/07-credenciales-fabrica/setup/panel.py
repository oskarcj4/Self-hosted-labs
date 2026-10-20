#!/usr/bin/env python3
"""Panel de administración de juguete del Lab 07. Lee las credenciales de
/etc/webadmin/credentials y responde si un intento de login coincide. Sirve
sólo para que se vea que las credenciales de fábrica 'admin/admin' funcionan."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

CREDS = "/etc/webadmin/credentials"


def load():
    data = {}
    try:
        with open(CREDS) as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    data[k.strip()] = v.strip()
    except OSError:
        pass
    return data


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        q = parse_qs(urlparse(self.path).query)
        c = load()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        if "u" in q and "p" in q:
            ok = q["u"][0] == c.get("username") and q["p"][0] == c.get("password")
            self.wfile.write(b"LOGIN OK\n" if ok else b"LOGIN FAIL\n")
        else:
            self.wfile.write(b"webadmin panel :: use ?u=USER&p=PASS to log in\n")


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
