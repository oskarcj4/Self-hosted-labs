#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
rm -f /var/log/app/orders.log.1
systemctl restart trace-collector
find /srv/sessions -type f -name 'sess-*' -mtime +1 -delete
cat > /etc/logrotate.d/app <<'EOF'
/var/log/app/*.log {
    daily
    rotate 7
    maxsize 20M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
sleep 2
