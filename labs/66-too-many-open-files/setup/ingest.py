#!/usr/bin/env python3
"""'ingest' en 127.0.0.1:8600. Al arrancar abre (y mantiene abiertos) todos
los lotes de /srv/ingest/inbox, como un pool de conexiones que crece con la
carga. Con un límite de descriptores bajo, se cae con EMFILE."""
import ctypes
import glob
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

INBOX = "/srv/ingest/inbox"
try:
    ctypes.CDLL(None).prctl(15, b"ingest", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass

files = sorted(glob.glob(INBOX + "/*.json"))
handles = []
for f in files:
    try:
        handles.append(open(f))
    except OSError as e:
        print(f"FATAL: no puedo abrir {f} (llevo {len(handles)} abiertos): {e}",
              file=sys.stderr, flush=True)
        sys.exit(1)
print(f"ingest: {len(handles)} lotes abiertos", flush=True)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = f"ingest ok {len(handles)} lotes\n".encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8600), H).serve_forever()
