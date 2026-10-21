#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cat > /usr/local/bin/catalog-watchdog.sh <<'EOF'
#!/bin/bash
# Watchdog de catalog: si /health no responde en 3 s, reinicia y avisa.
set -u
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
URL=http://127.0.0.1:8300/health

if curl -fs --max-time 3 -o /dev/null "$URL"; then
  exit 0
fi
logger -t catalog-watchdog "catalog no responde en $URL; reiniciando"
systemctl restart catalog
curl -s --max-time 5 -X POST \
     --data "catalog: /health sin respuesta en 3 s; catalog reiniciado por el watchdog ($(hostname) $(date '+%F %T'))" \
     http://127.0.0.1:9000/alert >/dev/null || logger -t catalog-watchdog "no pude enviar la alerta"
EOF
chmod 755 /usr/local/bin/catalog-watchdog.sh
cat > /etc/systemd/system/catalog-watchdog.service <<'EOF'
[Unit]
Description=Watchdog de catalog

[Service]
Type=oneshot
ExecStart=/usr/local/bin/catalog-watchdog.sh
TimeoutStartSec=60
EOF
cat > /etc/systemd/system/catalog-watchdog.timer <<'EOF'
[Unit]
Description=Lanza el watchdog de catalog cada 15 s

[Timer]
OnBootSec=30s
OnUnitActiveSec=15s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now catalog-watchdog.timer
