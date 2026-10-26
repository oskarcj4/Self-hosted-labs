#!/usr/bin/env bash
# Arranque del target. Monta el escenario y, segun el modo, abre shell (blue)
# o se queda sin terminal (red).
set -e
bash /opt/lab/setup/plant.sh
if [ "${TCLAB_MODE:-blue}" = "red" ]; then
  echo "[red] target levantado, sin shell. Atacalo por HTTP desde la caja atacante."
  exec tail -f /dev/null
else
  exec ttyd -p 7681 -W -t fontSize=14 bash -lc 'su - analista'
fi
