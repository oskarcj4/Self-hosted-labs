#!/usr/bin/env bash
# Solución BLUE del lab 106: sanear la ruta de /download y dejar de fiarse de la
# cabecera X-Admin. analista puede escribir /etc/panel/config.json.
set -e
CFG=/etc/panel/config.json
cat > "$CFG" <<JSON
{
  "sanitize_path": true,
  "trust_admin_header": false
}
JSON
app-reload
echo "Traversal cerrado y /admin ya no confia en X-Admin."
