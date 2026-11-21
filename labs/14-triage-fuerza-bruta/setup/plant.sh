#!/usr/bin/env bash
# Planta el escenario del Lab 14: auth.log de un ataque de fuerza bruta SSH.
set -e
mkdir -p /var/log /etc
python3 /opt/lab/gen_log.py
# Sin auth.log no hay lab: fallar a la vista en vez de dejar la terminal vacía.
[ -s /var/log/auth.log ] || { echo "ERROR: no se generó /var/log/auth.log" >&2; exit 1; }
touch /etc/hosts.deny
echo "Lab 14 plantado. Entra como analista y lee /RETO.md"
