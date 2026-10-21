#!/usr/bin/env python3
"""'minidb': base de datos de juguete. Lee /etc/minidb/minidb.conf
(listen_address, port), saluda con 'MINIDB 1.0 READY' y responde PONG a PING."""
import ctypes
import socketserver

CONF = "/etc/minidb/minidb.conf"
try:
    ctypes.CDLL(None).prctl(15, b"minidb", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass

cfg = {"listen_address": "127.0.0.1", "port": "5432"}
with open(CONF) as f:
    for line in f:
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = (x.strip() for x in line.split("=", 1))
            cfg[k] = v.strip("'\"")


class H(socketserver.StreamRequestHandler):
    def handle(self):
        self.wfile.write(b"MINIDB 1.0 READY\n")
        for raw in self.rfile:
            cmd = raw.strip().upper()
            if cmd == b"PING":
                self.wfile.write(b"PONG\n")
            elif cmd == b"QUIT":
                return
            else:
                self.wfile.write(b"ERR unknown command\n")


socketserver.ThreadingTCPServer.allow_reuse_address = True
socketserver.ThreadingTCPServer((cfg["listen_address"], int(cfg["port"])), H).serve_forever()
