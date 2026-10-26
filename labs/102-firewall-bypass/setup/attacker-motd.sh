#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 102 (RED) =================
 El nodo 'target' tiene un firewall mal configurado. Dos servicios
 internos deberian estar bloqueados:
    9001  servicio de usuario  -> bandera USER
    9002  consola admin (root) -> bandera ROOT
 Dos reglas erroneas dejan una via para alcanzarlos. Encuentrala.

 NO tienes shell en el target: solo acceso de RED desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
