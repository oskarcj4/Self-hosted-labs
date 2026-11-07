#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/app

# 1. La app maneja SIGTERM: deja de aceptar, termina lo que tiene en curso y sale con 0.
python3 - <<'PY'
p = "app.py"
s = open(p).read()
s = s.replace("import subprocess, time", "import signal, subprocess, sys, threading, time")
s = s.replace('''log("arrancando en :8000")
ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()''', '''srv = ThreadingHTTPServer(("0.0.0.0", 8000), H)
srv.daemon_threads = False          # server_close() espera a las peticiones en curso


def parar(signum, frame):
    log("SIGTERM: dejo de aceptar peticiones y termino las que están en curso")
    threading.Thread(target=srv.shutdown).start()


signal.signal(signal.SIGTERM, parar)
signal.signal(signal.SIGINT, parar)
log("arrancando en :8000")
srv.serve_forever()
srv.server_close()
log("apagado limpio")
sys.exit(0)''')
open(p, "w").write(s)
PY

# 2. El shell no se queda de PID 1: exec.
sed -i 's/^python app.py$/exec python app.py/' entrypoint.sh

# 3. Forma exec en el Dockerfile.
sed -i 's#^CMD ./entrypoint.sh$#CMD ["./entrypoint.sh"]#' Dockerfile

# 4. Un init de verdad como PID 1 (tini): recoge huérfanos y reenvía señales.
python3 - <<'PY'
p = "compose.yaml"
s = open(p).read()
if "init: true" not in s:
    s = s.replace("    image: informes:dev\n", "    image: informes:dev\n    init: true\n    stop_grace_period: 20s\n")
open(p, "w").write(s)
PY
cat Dockerfile entrypoint.sh compose.yaml
docker compose up -d --build
echo "solve.sh completado."
