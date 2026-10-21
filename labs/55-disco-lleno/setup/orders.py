#!/usr/bin/env python3
"""Servicio 'orders' del escenario. Escribe en /var/log/app/orders.log y crea
sesiones en /srv/sessions. /health responde 200 sólo si puede hacer ambas cosas
(igual que una app real que se cae cuando el disco o los inodos se agotan)."""
import ctypes
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = "/var/log/app/orders.log"
SESS = "/srv/sessions"
try:
    ctypes.CDLL(None).prctl(15, b"orders", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


def write_log(msg):
    with open(LOG, "a") as f:
        f.write(time.strftime("%Y-%m-%dT%H:%M:%S ") + msg + "\n")


def probe():
    write_log("INFO health probe")
    p = os.path.join(SESS, f".probe-{os.getpid()}")
    with open(p, "w") as f:
        f.write("ok")
    os.remove(p)


def ticker():
    n = 0
    while True:
        n += 1
        try:
            write_log(f"INFO order #{n} processed")
        except OSError:
            pass
        time.sleep(2)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            probe()
            code, body = 200, b"orders ok\n"
        except OSError as e:
            code, body = 500, f"orders ERROR: {e}\n".encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


threading.Thread(target=ticker, daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
