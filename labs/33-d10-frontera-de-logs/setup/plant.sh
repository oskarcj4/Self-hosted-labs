#!/usr/bin/env bash
# Lab 33 (Día 10): los logs de pagos (con tokens) son legibles/escribibles
# por todos, la carpeta es 0777 y logrotate recrea el log como 0666.
set -e
id payments >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin payments
install -d -m 0755 /opt/payments
install -m 0755 /opt/lab/setup/paymentsd.py /opt/payments/paymentsd.py
L=/var/log/payments
install -d -m 0777 -o root -g root "$L"
for i in $(seq 1 40); do
  echo "2026-10-17T0$((i % 10)):1$((i % 6)):00 txn=$((300000000 + i*7919)) amount=$((i*13)).00EUR card=****$((4000 + i*37)) token=tok_$(printf '%012x' $((i*2654435761)))"
done > "$L/transactions.log.1"
: > "$L/transactions.log"
chmod 0644 "$L/transactions.log.1"
chmod 0666 "$L/transactions.log"

cat > /etc/logrotate.d/payments <<'EOF'
/var/log/payments/*.log {
    daily
    rotate 7
    missingok
    notifempty
    create 0666 root root
}
EOF

cat > /etc/systemd/system/paymentsd.service <<'EOF'
[Unit]
Description=paymentsd (registro de transacciones)
After=network.target

[Service]
User=payments
Group=payments
ExecStart=/usr/bin/python3 /opt/payments/paymentsd.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now paymentsd
echo "Lab 33 plantado."
