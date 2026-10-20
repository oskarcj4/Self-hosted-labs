"""reports-worker: resume /app/data/pedidos.csv en /out/report.txt cada 10 s.
Con DEBUG=1 abre además un depurador remoto en :5678 (sólo para desarrollo)."""
import csv
import os
import socket
import threading
import time


def debug_server():
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", 5678))
    s.listen()
    while True:
        c, _ = s.accept()
        c.sendall(b"remote-debugger: attached (sin autenticacion)\n")
        c.close()


if os.environ.get("DEBUG") == "1":
    threading.Thread(target=debug_server, daemon=True).start()

with open("/app/data/pedidos.csv") as f:
    rows = list(csv.DictReader(f))
total = sum(float(r["importe"]) for r in rows)

while True:
    with open("/out/report.txt", "w") as f:
        f.write(f"pedidos={len(rows)} importe={total:.2f}\n")
    time.sleep(10)
