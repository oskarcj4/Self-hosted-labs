#!/usr/bin/env bash
# Lab 114: bastión SSH con contraseñas activadas, sin fail2ban, y un bot
# probando contraseñas en vivo. auth.log.1 trae el histórico de ayer.
set -e
systemctl enable --now rsyslog
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/; s/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
echo 'root:Primavera2024!' | chpasswd
systemctl enable --now ssh
# fail2ban instalado pero parado y sin jail propia.
systemctl disable --now fail2ban >/dev/null 2>&1 || true
rm -f /etc/fail2ban/jail.local /etc/fail2ban/jail.d/*.local

# Histórico de ayer (rotado): 4 orígenes, uno de ellos interno y legítimo.
python3 - <<'PY'
import random, datetime
random.seed(114)
src = [("185.220.101.7", 412), ("45.155.205.233", 233), ("103.145.13.90", 97), ("10.20.0.15", 2)]
users = ["admin", "test", "oracle", "ubuntu", "git", "postgres", "user"]
ev = []
day = datetime.datetime.now() - datetime.timedelta(days=1)
for ip, n in src:
    for _ in range(n):
        t = day.replace(hour=0, minute=0, second=0) + datetime.timedelta(seconds=random.randint(0, 86000))
        if ip == "10.20.0.15":
            ev.append((t, f"Failed password for operador from {ip} port {random.randint(40000,65000)} ssh2"))
        elif random.random() < 0.6:
            ev.append((t, f"Failed password for root from {ip} port {random.randint(40000,65000)} ssh2"))
        else:
            ev.append((t, f"Failed password for invalid user {random.choice(users)} from {ip} port {random.randint(40000,65000)} ssh2"))
for h in (8, 13, 17):
    t = day.replace(hour=h, minute=2, second=11)
    ev.append((t, f"Accepted publickey for operador from 10.20.0.15 port 51022 ssh2: ED25519 SHA256:q1w2e3r4t5y6u7i8o9p0"))
ev.sort()
with open("/var/log/auth.log.1", "w") as f:
    for t, m in ev:
        f.write(f"{t.strftime('%b %e %H:%M:%S')} bastion-114 sshd[{random.randint(1000,30000)}]: {m}\n")
PY
chown root:adm /var/log/auth.log.1; chmod 0640 /var/log/auth.log.1
usermod -aG adm analista

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-114.txt <<'TXT'
INC-114 · bastion-114
auth.log está lleno de "Failed password" y sigue creciendo ahora mismo.
1) Con el histórico de ayer (/var/log/auth.log.1): ¿cuántos intentos fallidos
   hubo y qué IP es la que más lo intentó?
2) Frenar los intentos repetidos (fail2ban, 3 fallos y fuera).
3) Pasar a autenticación SÓLO con llave (sin perder tu acceso).
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 114 plantado."
