#!/usr/bin/env bash
# Planta el escenario del Lab 01: un intruso que ganó acceso SSH y dejó
# varios mecanismos de persistencia. Todo es inofensivo.
set -e

ATTACKER_IP="185.220.101.47"
ROGUE_COMMENT="mallory@evil"

# 1) Llave SSH rogue del atacante en authorized_keys del analista
mkdir -p /home/analista/.ssh
cat > /home/analista/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+FakeKeyForLabOnlyDoNotUseThisKeyAnywhere00000 analista@prod-web-01
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM+R0gUeKeYpLaNtEdByAtTaCkErLaB0000000000000000 ${ROGUE_COMMENT}
EOF
chown -R analista:analista /home/analista/.ssh
chmod 600 /home/analista/.ssh/authorized_keys

# 2) Payload oculto en memoria compartida + trampa en el .bashrc del analista
cat > /dev/shm/.update <<'EOF'
# [payload de laboratorio - inofensivo]
# En un ataque real esto reabriría una conexión al atacante.
echo "[trap] .bashrc payload would run here" >> /tmp/.pwned_marker 2>/dev/null || true
EOF
chmod 644 /dev/shm/.update

# Línea trampa camuflada al final del .bashrc
cat >> /home/analista/.bashrc <<'EOF'

# ---- actualizacion automatica del sistema ----
[ -f /dev/shm/.update ] && source /dev/shm/.update
# ----------------------------------------------
EOF
chown analista:analista /home/analista/.bashrc

# 3) Pista en el log de autenticación (de dónde vino el intruso)
mkdir -p /var/log
cat >> /var/log/auth.log <<EOF
$(date '+%b %e %H:%M:%S') prod-web-01 sshd[2048]: Accepted publickey for analista from ${ATTACKER_IP} port 51234 ssh2: ED25519 SHA256:rOgUeKeYlAbOnLy
$(date '+%b %e %H:%M:%S') prod-web-01 sshd[2048]: pam_unix(sshd:session): session opened for user analista by (uid=0)
EOF

echo "Lab 01 plantado. Entra como analista y lee /RETO.md"
