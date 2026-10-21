#!/usr/bin/env python3
"""'report-gen': cada 5 s genera un informe cargando un lote en memoria.
La memoria que usa depende de BATCH_SIZE (~200 bytes por registro) en
/etc/report-gen.conf. Al terminar cada informe escribe last-report.json."""
import ctypes
import json
import os
import time

try:
    ctypes.CDLL(None).prctl(15, b"report-gen", 0, 0, 0)
except Exception:  # noqa: BLE001
    pass

cfg = {}
with open("/etc/report-gen.conf") as f:
    for line in f:
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
batch = int(cfg.get("BATCH_SIZE", "100000"))
out = "/var/lib/report-gen/last-report.json"
print(f"report-gen arrancando: BATCH_SIZE={batch}", flush=True)
n = 0
while True:
    n += 1
    print(f"informe #{n}: cargando {batch} registros", flush=True)
    data = b"\x01" * (batch * 200)        # memoria realmente escrita (no perezosa)
    time.sleep(1)
    tmp = out + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"informe": n, "registros": batch, "bytes": len(data),
                   "ts": time.time()}, f)
    os.replace(tmp, out)
    del data
    time.sleep(4)
