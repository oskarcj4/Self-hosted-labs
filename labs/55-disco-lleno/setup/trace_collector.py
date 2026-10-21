#!/usr/bin/env python3
"""'trace-collector': abre /var/log/app/debug-trace.log UNA vez y lo mantiene
abierto mientras vive (como muchos demonios). La primera vez que arranca vuelca
40 MB de trazas de depuración; después escribe una línea cada 5 segundos."""
import ctypes
import os
import time

LOG = "/var/log/app/debug-trace.log"
STATE = "/var/lib/trace-collector/.filled"
try:
    ctypes.CDLL(None).prctl(15, b"trace-collector", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass

f = open(LOG, "a", buffering=1)
if not os.path.exists(STATE):
    line = "2026-10-19T22:41:07 DEBUG trace span=checkout.render cache=miss " + "x" * 120 + "\n"
    chunk = line * (1024 * 1024 // len(line))
    for _ in range(40):
        f.write(chunk)
    f.flush()
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    open(STATE, "w").close()
while True:
    try:
        f.write(time.strftime("%Y-%m-%dT%H:%M:%S") + " DEBUG heartbeat\n")
    except OSError:
        pass
    time.sleep(5)
