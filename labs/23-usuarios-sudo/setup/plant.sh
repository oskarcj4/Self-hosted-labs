#!/usr/bin/env bash
# Planta el escenario del Lab 23: la cuenta devops con sudo total sin contraseña.
set -e
id devops >/dev/null 2>&1 || useradd -m -s /bin/bash devops
cat > /etc/sudoers.d/devops <<'EOF'
# puesto "para ir rápido": sudo total sin contraseña (demasiado permiso)
devops ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/devops
echo "Lab 23 plantado. Entra como analista y lee /RETO.md"
