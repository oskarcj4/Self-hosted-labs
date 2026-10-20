#!/usr/bin/env bash
# Planta el escenario del Lab 10: una copia de bash con bit SUID-root, camuflada
# como archivo de sistema. Inofensivo (es sólo una copia de bash).
set -e

cp /bin/bash /usr/bin/.dbus-cache
chown root:root /usr/bin/.dbus-cache
chmod 4755 /usr/bin/.dbus-cache     # 4xxx = bit SUID

echo "Lab 10 plantado. Entra como analista y lee /RETO.md"
