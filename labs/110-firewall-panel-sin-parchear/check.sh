#!/usr/bin/env bash
# Dispatcher del Lab 110. La vía RED se valida enviando las banderas por la web
# (lo hace el servidor). Aquí solo se comprueba la vía BLUE: panel parcheado y
# CVE cerrado, con el firewall intacto.
SOLVED_MARKER=/tmp/.tclab-solved

echo "== Vía BLUE (actualizar el panel) =="
if bash /opt/lab/check-blue.sh; then
  echo "---------------------------------------"
  echo "🎉 Lab 110 resuelto por la vía blue. Se autodestruirá en ~1 minuto."
  touch "$SOLVED_MARKER"
  exit 0
fi
echo "---------------------------------------"
echo "Aún no. Actualiza con 'webmin-update' y vuelve a comprobar."
exit 1
