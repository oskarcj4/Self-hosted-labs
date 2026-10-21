#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
mkdir -p /etc/systemd/system/payments-worker.service.d
cat > /etc/systemd/system/payments-worker.service.d/override.conf <<'EOF'
[Service]
EnvironmentFile=
EnvironmentFile=/etc/payments/payments.env
EOF
systemctl daemon-reload
systemctl stop debug-9090
systemctl reset-failed payments-worker
systemctl restart payments-worker
sleep 2
