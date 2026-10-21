#!/usr/bin/env bash
# Lab 60: un servicio muere cada pocos segundos sin dejar error en su log. Lo
# mata el OOM killer del cgroup (MemoryMax) porque alguien subió el lote.
set -e
id report >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin report
install -m 0755 /opt/lab/setup/report_gen.py /usr/local/lib/report_gen.py
mkdir -p /var/lib/report-gen && chown report:report /var/lib/report-gen

cat > /etc/report-gen.conf <<'EOF'
# report-gen — configuración
# Registros por lote. Cada registro ocupa ~200 bytes en memoria.
# Probado en producción con 100000 (≈20 MB). Ticket PERF-77: "subir para ir más rápido".
BATCH_SIZE=500000
EOF

cat > /etc/systemd/system/report-gen.service <<'EOF'
[Unit]
Description=report-gen (informes nocturnos)
After=network.target

[Service]
User=report
ExecStart=/usr/bin/python3 /usr/local/lib/report_gen.py
Restart=on-failure
RestartSec=3
# Presupuesto de memoria del servicio en este host compartido.
MemoryMax=64M
MemorySwapMax=0

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now report-gen

mkdir -p /home/analista/ticket /home/analista/incidente
cat > /home/analista/ticket/INC-6230.txt <<'EOF'
INC-6230 · batch-01 · report-gen
- Los informes no salen desde el despliegue de esta mañana.
- "El servicio está active, lo he mirado" (guardia).
- "En el log de la aplicación no hay ni un error" (desarrollo).
- Cambio de esta mañana: PERF-77 (ajuste de rendimiento de report-gen).
Deja en ~/incidente/causa.txt la línea del journal que demuestra la causa.
EOF
chown -R analista:analista /home/analista/ticket /home/analista/incidente
echo "Lab 60 plantado."
