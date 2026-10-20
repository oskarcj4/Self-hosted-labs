"""log-collector: cada 3 s cuenta niveles en /logs/app.log y escribe el
resumen en /out/summary.txt."""
import collections
import time

while True:
    c = collections.Counter()
    try:
        with open("/logs/app.log") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 3:
                    c[parts[2]] += 1
    except OSError as e:
        print(f"no puedo leer el log: {e}", flush=True)
    with open("/out/summary.txt", "w") as f:
        f.write(" ".join(f"{k}={c[k]}" for k in ("INFO", "WARN", "ERROR")) + "\n")
    time.sleep(3)
