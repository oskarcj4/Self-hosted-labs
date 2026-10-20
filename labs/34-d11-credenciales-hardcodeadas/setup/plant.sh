#!/usr/bin/env bash
# Lab 34 (Día 11): un script de mantenimiento con la contraseña de la BD
# escrita dentro (legible por todos) y una copia .orig igual.
set -e
id dbsim >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin dbsim
install -d -m 0755 /opt/dbsim /opt/maint
install -m 0755 /opt/lab/setup/dbsim.py /opt/dbsim/dbsim.py
install -m 0755 -o root -g root /opt/lab/setup/db-maintenance.sh /opt/maint/db-maintenance.sh
install -m 0644 /opt/lab/setup/db-maintenance.sh /opt/maint/db-maintenance.sh.orig

cat > /etc/systemd/system/dbsim.service <<'EOF'
[Unit]
Description=dbsim (BD de pedidos simulada)
After=network.target

[Service]
User=dbsim
ExecStart=/usr/bin/python3 /opt/dbsim/dbsim.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/cron.d/db-maint <<'EOF'
# Mantenimiento nocturno de la BD de pedidos
30 3 * * * root /opt/maint/db-maintenance.sh >> /var/log/db-maint.log 2>&1
EOF
chmod 0644 /etc/cron.d/db-maint
systemctl daemon-reload
systemctl enable --now dbsim cron
echo "Lab 34 plantado."
