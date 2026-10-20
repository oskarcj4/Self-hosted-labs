#!/usr/bin/env bash
# Entrada de la terminal web: espera a que el escenario esté plantado y abre
# una sesión como 'analista'.
if [ ! -e /run/tclab-ready ] && [ ! -e /run/tclab-failed ]; then
  printf 'Preparando el escenario'
  for _ in $(seq 1 240); do
    [ -e /run/tclab-ready ] || [ -e /run/tclab-failed ] && break
    printf '.'; sleep 1
  done
  echo
fi
if [ -e /run/tclab-failed ]; then
  echo "[!] El escenario no se plantó bien. Detalle: sudo cat /var/log/tclab-plant.log"
fi
clear 2>/dev/null
echo "Lab 26 listo. Lee el reto con:  cat /RETO.md"
exec su - analista
