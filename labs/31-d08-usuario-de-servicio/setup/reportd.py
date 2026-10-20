#!/usr/bin/env python3
"""reportd: genera un informe cada 5 s en /var/lib/reportd/reports, registra
en /var/log/reportd/reportd.log y expone /health en 127.0.0.1:8400.
Lee su configuración de /etc/reportd/reportd.conf al arrancar."""
import ctypes
import glob
import os
import pwd
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATA = "/var/lib/reportd/reports"
LOG = "/var/log/reportd/reportd.log"
try:
    ctypes.CDLL(None).prctl(15, b"reportd", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass

with open("/etc/reportd/reportd.conf") as f:   # falla al arrancar si no puede leerla
    CONF = dict(l.strip().split("=", 1) for l in f if "=" in l and not l.startswith("#"))

USER = pwd.getpwuid(os.geteuid()).pw_name
STATE = {"last": None, "error": None}


def loop():
    while True:
        try:
            name = f"{DATA}/report-{int(time.time())}.txt"
            with open(name, "w") as f:
                f.write(f"{CONF.get('REPORT_TITLE', 'Informe')} — {time.ctime()}\n")
            with open(LOG, "a") as f:
                f.write(f"{time.ctime()} generado {name} (usuario {USER})\n")
            for old in sorted(glob.glob(f"{DATA}/report-*.txt"))[:-20]:
                os.remove(old)
            STATE.update(last=name, error=None)
        except OSError as e:
            STATE["error"] = f"{e.strerror}: {e.filename}"
        time.sleep(5)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if STATE["error"]:
            code, body = 500, f"reportd ERROR user={USER} {STATE['error']}\n"
        else:
            code, body = 200, f"reportd ok user={USER} last={STATE['last']}\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


threading.Thread(target=loop, daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", 8400), H).serve_forever()
