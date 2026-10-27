#!/usr/bin/env bash
# Solución BLUE del lab 104: contraseña fuerte + errores callados, sin romper
# el panel. analista tiene permiso de escritura sobre /etc/panel/config.json.
set -e
CFG=/etc/panel/config.json

# Contraseña fuerte y aleatoria para el panel.
NEWPASS=$(head -c18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c20)

cat > "$CFG" <<EOF
{
  "panel_pass": "$NEWPASS",
  "verbose_errors": false
}
EOF

# Recargar el panel (lee config.json en cada petición, pero reiniciamos limpio).
app-reload

echo "Contraseña nueva del panel (admin:$NEWPASS). Errores verbosos: off."
