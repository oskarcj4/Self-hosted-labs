#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 104 (RED) =================
 El nodo 'target' expone un panel de borde en http://target:8080/.
 Dos cosas mal puestas dejan la puerta abierta:
    /panel    -> panel admin (bandera USER)  · prueba lo obvio primero
    /debug    -> cuando algo falla, habla de mas (bandera ROOT)

 NO tienes shell en el target: solo HTTP desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
