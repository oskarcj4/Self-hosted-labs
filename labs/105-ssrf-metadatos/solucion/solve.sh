#!/usr/bin/env bash
# Solución BLUE del lab 105: allowlist de destinos (default-deny) sin romper el
# health legítimo. analista puede escribir /etc/panel/config.json.
set -e
CFG=/etc/panel/config.json
cat > "$CFG" <<JSON
{
  "restrict_targets": true,
  "allowlist": ["http://status.lab:8080/health"]
}
JSON
app-reload
echo "SSRF cerrado: solo se permite el health de status.lab."
