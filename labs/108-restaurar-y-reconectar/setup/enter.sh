#!/usr/bin/env bash
if [ ! -e /run/tclab-ready ] && [ ! -e /run/tclab-failed ]; then
  printf 'Preparando el escenario'
  for _ in $(seq 1 240); do
    [ -e /run/tclab-ready ] || [ -e /run/tclab-failed ] && break
    printf '.'; sleep 1
  done
  echo
fi
[ -e /run/tclab-failed ] && echo "[!] El escenario no se plantó bien: sudo cat /var/log/tclab-plant.log"
clear 2>/dev/null
echo "Lab 108 listo. Lee el reto con:  cat /RETO.md"
exec su - analista
