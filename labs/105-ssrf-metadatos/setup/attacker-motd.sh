#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 105 (RED) =================
 El nodo 'target' expone un proxy de estado en http://target:8080/.
    /fetch?url=...   trae una URL DESDE el servidor.
 Dentro del target hay un servicio de metadatos que solo escucha en
 127.0.0.1:8081 y no deberia verse desde fuera... salvo a traves del proxy.
    127.0.0.1:8081/user   -> bandera USER
    127.0.0.1:8081/root   -> bandera ROOT

 NO tienes shell en el target: solo HTTP desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
