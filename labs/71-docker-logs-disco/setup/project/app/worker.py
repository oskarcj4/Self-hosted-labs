"""Worker de pedidos (lab 71). Con LOG_LEVEL=DEBUG vuelca el detalle de cada
mensaje de la cola (y al arrancar, toda la cola atrasada). Con INFO, un
resumen cada 5 s."""
import os
import sys
import time

DEBUG = os.environ.get("LOG_LEVEL", "INFO").upper() == "DEBUG"
BACKLOG = int(os.environ.get("BACKLOG", "0"))
PAD = "x" * 120
out = sys.stdout


def debug(n):
    out.write(f"DEBUG pedido={n} cola=pedidos estado=procesado payload={PAD}\n")


n = 0
if DEBUG:
    for n in range(BACKLOG):  # cola atrasada desde la caída del jueves
        debug(n)
    out.flush()
while True:
    if DEBUG:
        for _ in range(400):
            n += 1
            debug(n)
        out.flush()
        time.sleep(1)
    else:
        n += 25
        print(f"INFO procesados {n} pedidos", flush=True)
        time.sleep(5)
