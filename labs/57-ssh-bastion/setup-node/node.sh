#!/usr/bin/env bash
# Arranque de bastion / app-02 (lab 57). ROLE=bastion|app.
set -e
if [ ! -e /opt/.planted ]; then
  useradd -m -s /bin/bash deploy
  if [ "$ROLE" = bastion ]; then
    echo 'deploy:Bastion-2026' | chpasswd
  else
    echo 'deploy:App02-2026' | chpasswd
    # Un "arreglo rápido" de hace meses: home y authorized_keys abiertos a
    # todos. sshd (StrictModes) ignora las claves si los permisos son inseguros.
    mkdir -p /home/deploy/.ssh
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGq0dAntiguoPortatilDeAlguienQueYaNoEsta00 old-laptop' \
      > /home/deploy/.ssh/authorized_keys
    chown -R deploy:deploy /home/deploy
    chmod 0777 /home/deploy
    chmod 0777 /home/deploy/.ssh
    chmod 0666 /home/deploy/.ssh/authorized_keys
  fi
  cat > /etc/ssh/sshd_config.d/lab.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication yes
AllowTcpForwarding yes
EOF
  touch /opt/.planted
fi
mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
