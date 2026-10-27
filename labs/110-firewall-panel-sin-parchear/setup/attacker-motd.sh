#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 110 (RED) =================
 El appliance 'target' tiene el firewall BIEN configurado (lista
 blanca). No lo vas a 'saltar' por una regla floja: 22 y 8080
 internos estan realmente cerrados.

 Pero expone su panel de gestion Webmin en 10000 (HTTPS) y la
 version instalada esta SIN PARCHEAR. Hay un exploit publico que
 cruza por ahi hasta ejecucion de codigo en el appliance.
    80     web publica
    10000  panel Webmin (HTTPS)  <- version desactualizada
    USER + ROOT: banderas del appliance

 Identifica el servicio y su version, busca el CVE conocido y usalo.
 NO tienes shell en el target: solo acceso de RED desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
