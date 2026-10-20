"""thumbnailer: cada 2 s procesa los trabajos de /jobs/in: genera
/jobs/out/<nombre>.thumb y mueve el original a /jobs/done."""
import os
import shutil
import time

IN, OUT, DONE = "/jobs/in", "/jobs/out", "/jobs/done"

print(f"thumbnailer arrancado como uid={os.getuid()}", flush=True)
while True:
    for name in sorted(os.listdir(IN)):
        src = os.path.join(IN, name)
        try:
            with open(src, "rb") as f:
                data = f.read()
            with open(os.path.join(OUT, name + ".thumb"), "w") as f:
                f.write(f"thumb de {name}: {len(data)} bytes (uid {os.getuid()})\n")
            shutil.move(src, os.path.join(DONE, name))
            print(f"procesado {name}", flush=True)
        except OSError as e:
            print(f"ERROR con {name}: {e}", flush=True)
    time.sleep(2)
