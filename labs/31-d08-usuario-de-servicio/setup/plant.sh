#!/usr/bin/env bash
# Lab 31 (Día 08): reportd corre como root. Todo lo que toca (datos, log,
# config) pertenece a root, así que "simplemente poner User=" lo rompe.
set -e
install -d -m 0755 /opt/reportd
install -m 0755 /opt/lab/setup/reportd.py /opt/reportd/reportd.py
install -d -m 0755 /var/lib/reportd /var/lib/reportd/reports /var/log/reportd
install -d -m 0755 /etc/reportd
cat > /etc/reportd/reportd.conf <<'EOF'
REPORT_TITLE=Ventas diarias
REPORT_DB=postgres://reports@db-01/sales
EOF
chmod 0600 /etc/reportd/reportd.conf

cat > /etc/systemd/system/reportd.service <<'EOF'
[Unit]
Description=reportd (generador de informes)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/reportd/reportd.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now reportd
echo "Lab 31 plantado."
