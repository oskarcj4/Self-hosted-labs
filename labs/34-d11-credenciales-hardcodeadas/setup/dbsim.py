#!/usr/bin/env python3
"""dbsim: base de datos simulada en 127.0.0.1:5433. Protocolo de texto:
  AUTH <usuario> <contraseña>   -> OK auth | ERR auth
  VACUUM                        -> OK vacuum done (requiere AUTH previo)
"""
import ctypes
import hashlib
import socketserver

# usuario -> sha256 de la contraseña
USERS = {"maint": "cd1d5da042695a6d98ceeb343169a3172a8508016f5babbe51bb412e5bd5a81c"}
try:
    ctypes.CDLL(None).prctl(15, b"dbsim", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass


class H(socketserver.StreamRequestHandler):
    def handle(self):
        authed = False
        for raw in self.rfile:
            parts = raw.decode(errors="replace").strip().split(" ", 2)
            if parts[0] == "AUTH" and len(parts) == 3:
                authed = USERS.get(parts[1]) == hashlib.sha256(parts[2].encode()).hexdigest()
                self.wfile.write(b"OK auth\n" if authed else b"ERR auth\n")
            elif parts[0] == "VACUUM":
                self.wfile.write(b"OK vacuum done\n" if authed else b"ERR not authenticated\n")
            elif parts[0] == "QUIT":
                break


socketserver.ThreadingTCPServer.allow_reuse_address = True
socketserver.ThreadingTCPServer(("127.0.0.1", 5433), H).serve_forever()
