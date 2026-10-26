#!/usr/bin/env python3
"""API de la tienda (lab 108). Lee su cadena de conexión de /etc/tienda/db.conf
(una línea con formato DSN de libpq). Si la base no está o el DSN apunta mal,
/health devuelve 503 con el detalle: esa es la pista para reconectar."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg2

CONF = "/etc/tienda/db.conf"


def dsn():
    with open(CONF) as f:
        return f.read().strip()


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception:
            pass

    def do_GET(self):
        if self.path.startswith("/health"):
            try:
                c = psycopg2.connect(dsn(), connect_timeout=3)
                c.autocommit = True
                with c, c.cursor() as cur:
                    cur.execute("SELECT count(*) FROM productos")
                    n = cur.fetchone()[0]
                c.close()
                return self.reply(200, {"status": "ok", "productos": n})
            except Exception as e:
                return self.reply(503, {"status": "error", "detalle": str(e)[:200]})
        return self.reply(404, {"error": "not found"})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
