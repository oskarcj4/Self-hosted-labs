#!/usr/bin/env bash
# Planta el escenario del Lab 81: Apache vulnerable a Slowloris.
#   - mod_reqtimeout deshabilitado: no hay límite al tiempo de lectura de cabeceras.
# El reto es mitigar el slow-DoS sin romper a los clientes lentos legítimos.
set -e
echo "<h1>web-81 OK</h1>" > /var/www/html/index.html

# Quitar la defensa por defecto para que el ataque funcione.
a2dismod reqtimeout >/dev/null 2>&1 || true

rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
apachectl start >/dev/null 2>&1 || service apache2 start >/dev/null 2>&1 || true

chmod +r /opt/lab/slowtest.py 2>/dev/null || true
echo "Lab 81 plantado. Entra como analista y lee /RETO.md"
