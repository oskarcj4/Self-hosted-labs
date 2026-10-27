#!/usr/bin/env bash
# Arranque del target. Monta el escenario y, según el modo, abre shell (blue)
# o se queda sin terminal (red): en red solo se llega por la red interna.
set -e
bash /opt/lab/setup/plant.sh

if [ "${TCLAB_MODE:-blue}" = "red" ]; then
  echo "[red] target levantado, sin shell. Atácalo por la red desde la caja atacante."
  exec tail -f /dev/null
else
  exec ttyd -p 7681 -W -t fontSize=14 bash -lc 'su - analista'
fi
