#!/bin/sh
cat <<'EOF'

================= TerminalCero · Lab 106 (RED) =================
 El nodo 'target' expone un visor de documentos en http://target:8080/.
    /download?file=...   sirve ficheros... y no valida la ruta.
    /admin               se fia de una cabecera que mandas TU.

 Pistas:
    - Hay un fichero privado fuera de /srv/docs (bandera USER).
    - El panel admin confia en la cabecera X-Admin (bandera ROOT).

 NO tienes shell en el target: solo HTTP desde esta caja.
 Entrega cada bandera en la web (campos user y root).
===============================================================
EOF
printf ' target -> '; getent hosts target 2>/dev/null | awk '{print $1}' | head -1
echo
