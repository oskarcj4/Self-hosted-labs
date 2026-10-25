#!/usr/bin/env bash
# Dispatcher. El lab se da por resuelto por CUALQUIERA de las dos vías.
#   bash /opt/lab/check.sh         -> intenta BLUE y luego RED; marca si pasa
#   bash /opt/lab/check-blue.sh    -> solo el arreglo (no marca, no destruye)
#   bash /opt/lab/check-red.sh     -> solo la captura de flag (no marca)
D=/opt/lab
case "${1:-auto}" in
  blue) exec bash "$D/check-blue.sh" ;;
  red)  exec bash "$D/check-red.sh" ;;
esac
path=""
echo "== Vía BLUE (arreglar la vulnerabilidad) =="
if bash "$D/check-blue.sh"; then
  path=blue
else
  echo
  echo "== Vía RED (capturar la flag) =="
  bash "$D/check-red.sh" && path=red
fi
echo "---------------------------------------"
if [ -n "$path" ]; then
  touch /tmp/.tclab-solved 2>/dev/null
  echo "🎉 Lab 98 resuelto por la vía ${path}. Se autodestruirá en ~1 minuto."
  exit 0
fi
echo "Aún no: ni el arreglo (blue) ni la captura (red) están completos."
echo "Puedes atacar una sola vía con:  bash /opt/lab/check.sh red   |   blue"
exit 1
