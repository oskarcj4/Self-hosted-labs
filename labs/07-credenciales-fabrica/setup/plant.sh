#!/usr/bin/env bash
# Planta el escenario del Lab 07: un panel de administración con credenciales
# de fábrica (admin/admin). Inofensivo.
set -e

mkdir -p /etc/webadmin
cat > /etc/webadmin/credentials <<'EOF'
# Credenciales del panel de administración
username=admin
password=admin
EOF
chmod 600 /etc/webadmin/credentials

# Arranca el panel (sólo en localhost) para que se vea que las creds funcionan.
nohup python3 /opt/lab/panel.py >/var/log/webadmin.log 2>&1 &

echo "Lab 07 plantado. Entra como analista y lee /RETO.md"
