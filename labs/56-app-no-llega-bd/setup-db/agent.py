#!/usr/bin/env python3
"""Agente de inventario de db-01 (sólo lectura): GET /state devuelve las reglas
del firewall en ejecución, las guardadas en disco y los sockets en escucha.
Lo usa el validador del lab desde app-01."""
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def sh(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except Exception as e:  # noqa: BLE001
        return f"error: {e}\n"


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/state":
            self.send_error(404)
            return
        try:
            with open("/etc/iptables/rules.v4") as f:
                saved = f.read()
        except OSError:
            saved = ""
        body = ("## iptables\n" + sh(["iptables", "-S", "INPUT"])
                + "## rules.v4\n" + saved
                + "## listen\n" + sh(["ss", "-Hltn"])).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", 9100), H).serve_forever()
