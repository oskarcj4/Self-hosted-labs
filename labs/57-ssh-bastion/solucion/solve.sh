#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root en dev-01 y
# hace el trabajo como 'analista'. Las contraseñas provisionales se pasan con
# SSH_ASKPASS sólo para poder automatizar la prueba.
cat > /tmp/askpass.sh <<'EOF'
#!/bin/sh
case "$*" in *10.77.57.20*) echo App02-2026 ;; *) echo Bastion-2026 ;; esac
EOF
chmod 755 /tmp/askpass.sh
su - analista -c '
set -e
export SSH_ASKPASS=/tmp/askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0
ssh-keygen -q -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "analista@dev-01 pipeline"
cat > ~/.ssh/config <<EOF
Host bastion
    HostName 10.76.57.5
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new

Host app-02
    HostName 10.77.57.20
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump bastion
    StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config
ssh-copy-id -i ~/.ssh/id_ed25519.pub bastion
ssh-copy-id -i ~/.ssh/id_ed25519.pub app-02
ssh app-02 "chmod 755 ~; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; sed -i /old-laptop/d ~/.ssh/authorized_keys"
'
