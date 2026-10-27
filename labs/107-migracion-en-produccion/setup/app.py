#!/usr/bin/env python3
"""API de la tienda (lab 107). Dos endpoints cortos que golpean 'pedidos':
  GET /health   -> cuenta pedidos (lectura)
  POST /checkout-> inserta un pedido (escritura)
Si una migración toma un lock ACCESS EXCLUSIVE sobre la tabla, hasta estas
consultas triviales se quedan esperando: por eso 'todo muere' bajo carga.
"""
import json
import os
import random
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg2

DSN = os.environ.get("DSN", "host=127.0.0.1 dbname=tienda user=tienda password=tienda")


def db():
    # statement_timeout corto: una consulta bloqueada falla rápido en vez de
    # colgar el worker para siempre (así el usuario 've' los errores con k6).
    c = psycopg2.connect(DSN, connect_timeout=3,
                         options="-c statement_timeout=4000")
    c.autocommit = True
    return c


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
                with db() as c, c.cursor() as cur:
                    cur.execute("SELECT count(*) FROM pedidos")
                    n = cur.fetchone()[0]
                return self.reply(200, {"status": "ok", "pedidos": n})
            except Exception as e:
                return self.reply(503, {"status": "error", "detalle": str(e)[:200]})
        return self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path.startswith("/checkout"):
            try:
                with db() as c, c.cursor() as cur:
                    cur.execute(
                        "INSERT INTO pedidos(cliente,total) VALUES (%s,%s) RETURNING id",
                        ("cliente-%d" % random.randint(1, 500),
                         random.randint(100, 20000)))
                    pid = cur.fetchone()[0]
                return self.reply(201, {"pedido": pid})
            except Exception as e:
                return self.reply(503, {"status": "error", "detalle": str(e)[:200]})
        return self.reply(404, {"error": "not found"})


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
