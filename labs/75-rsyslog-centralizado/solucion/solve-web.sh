#!/usr/bin/env bash
# Solución automática para web-02 (sirve para probar el lab). Corre como root en web-02.
set -e
mkdir -p /var/spool/rsyslog
cat > /etc/rsyslog.d/90-remoto.conf <<'EOF'
# Envío al colector central por TCP, con cola en disco y reintentos infinitos.
action(type="omfwd" target="log-01" port="514" protocol="tcp"
       queue.type="LinkedList" queue.filename="fwd_log01"
       queue.maxDiskSpace="200m" queue.saveOnShutdown="on"
       action.resumeRetryCount="-1" action.resumeInterval="5")
EOF
rsyslogd -N1 2>&1 | tail -1
systemctl restart rsyslog
