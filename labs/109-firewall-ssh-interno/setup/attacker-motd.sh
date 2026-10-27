#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 109 (RED) =================
 El nodo 'target' tiene un firewall que presume de dejar solo la web
 publica (80). Detras deberian estar cerrados:
    22    SSH de mantenimiento      -> camino a la bandera USER
    8080  consola admin interna     -> bandera ROOT (corre como root)

 El firewall se puede saltar hasta el SSH interno. Desde ahi, la red
 interna del nodo queda a tu alcance. Encuentra la via.

 NO tienes shell en el target: solo acceso de RED desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
