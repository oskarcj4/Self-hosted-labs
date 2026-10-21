#!/usr/bin/env bash
# Lab 64: 'catalog' se cuelga a veces (proceso vivo, sin respuesta) y nadie se
# entera. No hay ningún watchdog; el receptor de alertas sí existe.
set -e
for u in catalog alertd; do id $u >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin $u; done
install -m 0755 /opt/lab/setup/catalog.py /usr/local/lib/catalog.py
install -m 0755 /opt/lab/setup/alertd.py /usr/local/lib/alertd.py

cat > /etc/systemd/system/catalog.service <<'EOF'
[Unit]
Description=catalog (API de productos)
After=network.target

[Service]
User=catalog
RuntimeDirectory=catalog
ExecStart=/usr/bin/python3 /usr/local/lib/catalog.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/alertd.service <<'EOF'
[Unit]
Description=alertd (receptor de alertas del equipo)
After=network.target

[Service]
User=alertd
LogsDirectory=alerts
ExecStart=/usr/bin/python3 /usr/local/lib/alertd.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now catalog alertd

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/PROB-6404.txt <<'EOF'
PROB-6404 · cat-01 · catalog se queda colgado
- Tres veces este mes: catalog deja de responder. 'systemctl status' dice
  "active (running)" y Restart=on-failure no hace nada (el proceso no muere).
- Nos enteramos por los clientes, 40 minutos tarde. El arreglo siempre es
  'systemctl restart catalog'. Desarrollo busca el deadlock; mientras tanto:

  Tarea: un watchdog que cada 30 s como mucho compruebe
  http://127.0.0.1:8300/health (máximo 3 s de espera). Si no responde, que
  reinicie catalog y avise al equipo con un POST a http://127.0.0.1:9000/alert
  (el texto debe mencionar "catalog").
  Script: /usr/local/bin/catalog-watchdog.sh
- Si catalog está sano, el watchdog no debe tocar nada.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 64 plantado."
