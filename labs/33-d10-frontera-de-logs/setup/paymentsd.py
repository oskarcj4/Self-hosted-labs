#!/usr/bin/env python3
"""paymentsd: registra cada transacción en /var/log/payments/transactions.log
(abre el fichero en cada escritura, así sigue funcionando tras logrotate)."""
import ctypes
import random
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = "/var/log/payments/transactions.log"
STATE = {"ok": None, "err": None}
try:
    ctypes.CDLL(None).prctl(15, b"paymentsd", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


def loop():
    while True:
        line = (f"{time.strftime('%Y-%m-%dT%H:%M:%S')} txn={random.randint(10**8, 10**9)} "
                f"amount={random.randint(5, 900)}.{random.randint(0, 99):02d}EUR "
                f"card=****{random.randint(1000, 9999)} token=tok_{random.getrandbits(48):012x}\n")
        try:
            with open(LOG, "a") as f:
                f.write(line)
            STATE.update(ok=time.time(), err=None)
        except OSError as e:
            STATE["err"] = f"{e.strerror}: {e.filename}"
        time.sleep(2)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if STATE["err"]:
            code, body = 500, f"paymentsd ERROR {STATE['err']}\n"
        else:
            code, body = 200, "paymentsd ok\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a):
        pass


threading.Thread(target=loop, daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", 8600), H).serve_forever()
