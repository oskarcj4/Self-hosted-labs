#!/usr/bin/env bash
# Planta el escenario del Lab 80: Apache con una configuración floja frente a DoS.
#   - mod_reqtimeout deshabilitado (sin límite de tiempo de lectura)
#   - mod_evasive deshabilitado (sin límite de peticiones por IP)
#   - Timeout altísimo (300) y KeepAliveTimeout largo (65)
# El reto es endurecerlo para aguantar un flood HTTP.
set -e

# Página de prueba
echo "<h1>web-80 OK</h1>" > /var/www/html/index.html

# Aflojar la config por defecto
a2dismod reqtimeout >/dev/null 2>&1 || true
a2dismod evasive   >/dev/null 2>&1 || true

# Timeout y KeepAlive generosos (malo para DoS)
sed -i 's/^Timeout .*/Timeout 300/' /etc/apache2/apache2.conf 2>/dev/null || true
grep -q '^Timeout ' /etc/apache2/apache2.conf || echo 'Timeout 300' >> /etc/apache2/apache2.conf
sed -i 's/^KeepAliveTimeout .*/KeepAliveTimeout 65/' /etc/apache2/apache2.conf 2>/dev/null || true
grep -q '^KeepAliveTimeout ' /etc/apache2/apache2.conf || echo 'KeepAliveTimeout 65' >> /etc/apache2/apache2.conf

# Arrancar Apache (sin systemd)
rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
apachectl start >/dev/null 2>&1 || service apache2 start >/dev/null 2>&1 || true

echo "Lab 80 plantado. Entra como analista y lee /RETO.md"
