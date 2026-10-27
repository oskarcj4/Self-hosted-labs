#!/usr/bin/env bash
# Dispatcher del Lab 109. En este lab la vía RED se valida enviando las
# banderas por la web (lo hace el servidor). Aquí solo se comprueba la vía
# BLUE: que el firewall ya no se pueda saltar hasta el SSH.
SOLVED_MARKER=/tmp/.tclab-solved

echo "== Vía BLUE (arreglar el firewall) =="
if bash /opt/lab/check-blue.sh; then
  echo "---------------------------------------"
  echo "🎉 Lab 109 resuelto por la vía blue. Se autodestruirá en ~1 minuto."
  touch "$SOLVED_MARKER"
  exit 0
fi
echo "---------------------------------------"
echo "Aún no. Revisa /srv/fw/rules.sh, aplica con fw-reload y vuelve a comprobar."
exit 1
