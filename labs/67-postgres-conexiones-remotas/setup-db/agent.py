#!/usr/bin/env python3
"""Agente de estado de pg-01 (sólo lectura) para el validador del lab 67.
GET /state devuelve listen_addresses efectivo y las reglas de pg_hba.conf."""
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SQL = ("SELECT 'listen|' || current_setting('listen_addresses') "
       "UNION ALL SELECT 'rule|' || line_number || '|' || type || '|' "
       "|| array_to_string(database, ',') || '|' || array_to_string(user_name, ',') || '|' "
       "|| coalesce(address, '') || '|' || coalesce(netmask, '') || '|' || auth_method "
       "FROM pg_hba_file_rules WHERE error IS NULL")


def state():
    r = subprocess.run(["runuser", "-u", "postgres", "--", "psql", "-XAt", "-c", SQL],
                       capture_output=True, text=True, timeout=10)
    return r.stdout if r.returncode == 0 else "error|postgres no responde\n"


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (state() if self.path == "/state" else "uso: GET /state\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 9100), H).serve_forever()
