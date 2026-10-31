#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
N=$(grep -c "Failed password" /var/log/auth.log.1)
TOP=$(grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
printf 'intentos=%s\ntop=%s\n' "$N" "$TOP" > /home/analista/respuestas.txt
chown analista:analista /home/analista/respuestas.txt

cat > /etc/fail2ban/jail.local <<'J'
[sshd]
enabled  = true
backend  = auto
logpath  = /var/log/auth.log
maxretry = 3
findtime = 10m
bantime  = 1h
J
systemctl enable fail2ban
systemctl restart fail2ban
# Primero ver al bot baneado (con contraseñas aún activas genera "Failed password").
for _ in $(seq 1 60); do fail2ban-client status sshd | grep -q 'Banned IP list:.*[0-9]' && break; sleep 2; done

# Llave para analista ANTES de cerrar las contraseñas.
su - analista -c 'test -f ~/.ssh/id_ed25519 || ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519; cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
cat > /etc/ssh/sshd_config.d/10-solo-llave.conf <<'C'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
C
sed -i 's/^PasswordAuthentication yes/#&/; s/^PermitRootLogin yes/#&/' /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
fail2ban-client status sshd
