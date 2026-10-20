#!/usr/bin/env bash
# Planta el escenario del Lab 05: una segunda cuenta con UID 0 (backdoor) y
# una regla de sudo sin contraseña para una cuenta inocente. Inofensivo.
set -e

# 1) Cuenta backdoor con UID 0 (root alternativo), camuflada como servicio.
if ! awk -F: '$1=="supportsvc"' /etc/passwd | grep -q supportsvc; then
  echo 'supportsvc:x:0:0:System Support Service:/root:/bin/bash' >> /etc/passwd
  echo 'supportsvc:!:19700:0:99999:7:::' >> /etc/shadow
fi

# 2) Usuario normal 'backup' con una regla de sudo sin contraseña (persistencia).
id backup >/dev/null 2>&1 || useradd -m -s /bin/bash backup
cat > /etc/sudoers.d/backup <<'EOF'
# dejado por el atacante: sudo total sin contraseña
backup ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/backup

echo "Lab 05 plantado. Entra como analista y lee /RETO.md"
