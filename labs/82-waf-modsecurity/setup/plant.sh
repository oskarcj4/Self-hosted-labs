#!/usr/bin/env bash
# Planta el escenario del Lab 82: ModSecurity + OWASP CRS instalados, pero el
# motor en DetectionOnly: ve los ataques y los apunta en el log, pero NO los
# bloquea. En Debian el paquete libapache2-mod-security2 ya cablea el CRS
# (/etc/apache2/mods-available/security2.conf incluye /usr/share/modsecurity-crs/*.load);
# lo que falta es ENCENDER el motor. Ése es el reto.
set -e
echo "<h1>web-82 OK</h1>" > /var/www/html/index.html

a2enmod security2 >/dev/null 2>&1 || true

# modsecurity.conf en DetectionOnly (sólo registra, no bloquea)
mkdir -p /etc/modsecurity
cp -n /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf 2>/dev/null || true
if grep -q '^SecRuleEngine' /etc/modsecurity/modsecurity.conf; then
  sed -i 's/^SecRuleEngine.*/SecRuleEngine DetectionOnly/' /etc/modsecurity/modsecurity.conf
else
  echo 'SecRuleEngine DetectionOnly' >> /etc/modsecurity/modsecurity.conf
fi

rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
apachectl start >/dev/null 2>&1 || service apache2 start >/dev/null 2>&1 || true

echo "Lab 82 plantado. Entra como analista y lee /RETO.md"
