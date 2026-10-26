#!/bin/sh
# Solución BLUE del lab 103: cerrar las dos fugas de config y recargar.
# Escribe la config en el sitio (no renombra), así funciona como 'analista'.
set -e
sed 's/"serve_backup": true/"serve_backup": false/; s/"debug": true/"debug": false/' \
    /etc/panel/config.json > /tmp/panel.cfg
cat /tmp/panel.cfg > /etc/panel/config.json
rm -f /tmp/panel.cfg
app-reload
echo "config:"; cat /etc/panel/config.json
