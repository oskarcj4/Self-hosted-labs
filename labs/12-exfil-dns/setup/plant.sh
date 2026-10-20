#!/usr/bin/env bash
# Planta el escenario del Lab 12: log de consultas DNS con exfiltración hacia
# cdn-sync.io. Inofensivo (sólo un archivo de log).
set -e
mkdir -p /var/log /etc
python3 /opt/lab/gen_log.py
# archivo de blocklist vacío listo para que el analista añada el dominio
touch /etc/dns-blocklist.conf
echo "Lab 12 plantado. Entra como analista y lee /RETO.md"
