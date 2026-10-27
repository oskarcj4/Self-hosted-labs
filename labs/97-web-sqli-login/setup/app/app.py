#!/usr/bin/env python3
"""Portal de acceso de SogetiCorp. El login consulta la base SQLite.

El equipo anterior construyó la consulta concatenando strings. Funciona...
hasta que alguien escribe una comilla en el usuario.
"""
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

DB = "/srv/app/app.db"

FORM = b"""<!doctype html><meta charset=utf-8><title>SogetiCorp</title>
<h2>Portal interno</h2>
<form method=post action=/login>
  usuario: <input name=user><br>
  clave:   <input name=password type=password><br>
  <button>entrar</button>
</form>"""


def check_login(user, password):
    con = sqlite3.connect(DB)
    cur = con.cursor()
    # --- VULNERABLE: la entrada va directa a la consulta ---
    q = ("SELECT username, role, flag FROM users "
         "WHERE username = '%s' AND password = '%s'" % (user, password))
    try:
        rows = cur.execute(q).fetchall()
    except sqlite3.Error as e:
        con.close()
        return None, "sql-error: %s" % e
    con.close()
    return (rows[0] if rows else None), q


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/login"):
            self._send(200, FORM)
        else:
            self._send(404, "no")

    def do_POST(self):
        if self.path != "/login":
            return self._send(404, "no")
        n = int(self.headers.get("Content-Length", 0))
        data = parse_qs(self.rfile.read(n).decode(errors="replace"))
        user = data.get("user", [""])[0]
        password = data.get("password", [""])[0]
        row, _q = check_login(user, password)
        if not row:
            return self._send(401, "credenciales invalidas\n")
        username, role, flag = row
        body = "OK bienvenido=%s role=%s\n" % (username, role)
        if role == "admin":
            body += "flag=%s\n" % flag
        self._send(200, body)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), H).serve_forever()
