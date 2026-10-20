#!/usr/bin/env bash
# Lab 29 (Día 06): la clave de firma de billing-api es legible y escribible
# por cualquier usuario del sistema (0666) y su carpeta es 0777.
set -e
id billing >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin billing
install -d -m 0755 /opt/billing
install -m 0755 /opt/lab/setup/billing.py /opt/billing/billing.py
install -d -m 0777 /etc/billing
head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /etc/billing/secret.key
chmod 0666 /etc/billing/secret.key
chown root:root /etc/billing/secret.key
sha256sum /etc/billing/secret.key | cut -d' ' -f1 > /root/.tclab-secret.sha
chmod 600 /root/.tclab-secret.sha

cat > /etc/systemd/system/billing-api.service <<'EOF'
[Unit]
Description=billing-api (firma de facturas)
After=network.target

[Service]
User=billing
Group=billing
ExecStart=/usr/bin/python3 /opt/billing/billing.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now billing-api
echo "Lab 29 plantado."
