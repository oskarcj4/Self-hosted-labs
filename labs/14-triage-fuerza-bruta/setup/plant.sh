#!/usr/bin/env bash
# Planta el escenario del Lab 14: auth.log de un ataque de fuerza bruta SSH.
set -e
mkdir -p /var/log /etc
python3 /opt/lab/gen_log.py
touch /etc/hosts.deny
echo "Lab 14 plantado. Entra como analista y lee /RETO.md"
