#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 103 (RED) =================
 El nodo 'target' expone un panel web en http://target:8080/.
 Detras hay dos cosas mal puestas que dejan ver:
    /area?token=...   -> bandera USER
    /admin            -> bandera ROOT (consola admin)
 Un artefacto de build olvidado y un modo depuracion abren la via.

 NO tienes shell en el target: solo HTTP desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
