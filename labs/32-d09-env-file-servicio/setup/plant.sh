#!/usr/bin/env bash
# Lab 32 (Día 09): el EnvironmentFile del servicio (con secretos) es legible
# por todos, y hay una copia .bak igual de expuesta.
set -e
id notifier >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin notifier
install -d -m 0755 /opt/notifier /etc/notifier
install -m 0755 /opt/lab/setup/notifier.py /opt/notifier/notifier.py
cat > /etc/notifier/notifier.env <<'EOF'
# Secretos de notifier (cargados por systemd)
SMTP_HOST=smtp.interno.example
SMTP_USER=alertas
SMTP_PASSWORD=mXq-7Rt-notifier-2026
WEBHOOK_TOKEN=whk_9f8e7d6c5b4a3f2e1d
EOF
cp /etc/notifier/notifier.env /etc/notifier/notifier.env.bak
chmod 0644 /etc/notifier/notifier.env /etc/notifier/notifier.env.bak

cat > /etc/systemd/system/notifier.service <<'EOF'
[Unit]
Description=notifier (alertas SMTP / webhook)
After=network.target

[Service]
User=notifier
EnvironmentFile=/etc/notifier/notifier.env
ExecStart=/usr/bin/python3 /opt/notifier/notifier.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now notifier
echo "Lab 32 plantado."
