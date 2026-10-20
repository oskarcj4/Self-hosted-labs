#!/usr/bin/env bash
# Planta el escenario del Lab 17: sshd_config inseguro + host keys para que
# 'sshd -t' funcione.
set -e

# Genera host keys (necesarias para validar con 'sshd -t')
ssh-keygen -A >/dev/null 2>&1 || true
mkdir -p /run/sshd

cat > /etc/ssh/sshd_config <<'EOF'
# Configuración de SSH (INSEGURA por defecto - endurécela)
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
X11Forwarding yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

echo "Lab 17 plantado. Entra como analista y lee /RETO.md"
