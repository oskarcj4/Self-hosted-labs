#!/usr/bin/env bash
# Dispatcher del Lab 103. Via RED: enviar las banderas por la web (servidor).
# Aqui solo se valida la via BLUE: cerrar las dos fugas.
SOLVED_MARKER=/tmp/.tclab-solved
echo "== Via BLUE (cerrar las fugas) =="
if bash /opt/lab/check-blue.sh; then
  echo "---------------------------------------"
  echo "🎉 Lab 103 resuelto por la via blue. Se autodestruira en ~1 minuto."
  touch "$SOLVED_MARKER"; exit 0
fi
echo "---------------------------------------"
echo "Aun no. Edita /etc/panel/config.json, aplica con app-reload y reintenta."
exit 1
