#!/usr/bin/env bash
# Planta el escenario del Lab 06: una unidad de servicio + timer de systemd,
# disfrazada de "sys-health", que relanza un beacon inofensivo cada minuto.
set -e

cat > /etc/systemd/system/sys-health.service <<'EOF'
[Unit]
Description=System Health Reporter

[Service]
Type=oneshot
ExecStart=/opt/lab/.beacon.sh
EOF

cat > /etc/systemd/system/sys-health.timer <<'EOF'
[Unit]
Description=Run System Health Reporter every minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
Unit=sys-health.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now sys-health.timer 2>/dev/null || true

echo "Lab 06 plantado."
