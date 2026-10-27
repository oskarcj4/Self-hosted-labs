#!/usr/bin/env bash
# Solución BLUE: actualizar el panel de gestión. El firewall NO se toca (está
# bien). (La vía RED se deja al alumno.)
set -e
# webmin-do-update aplica el .deb parcheado (1.930) y reinicia el panel.
/usr/local/bin/webmin-do-update
echo "Panel actualizado. El CVE-2019-15107 queda cerrado."
