#!/usr/bin/env bash
# Lab 35 (Día 12): el token de la API va en Environment= de la unidad, así que
# se ve con "systemctl show/cat" y en /proc/<pid>/environ.
set -e
TOKEN="ing_live_4f7a9c2e8b1d6f3a5c0e"
id ingest >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin ingest
install -d -m 0755 /opt/ingest
HASH=$(printf '%s' "$TOKEN" | sha256sum | cut -c1-16)
sed "s/^OK_HASH = .*/OK_HASH = \"$HASH\"/" /opt/lab/setup/ingest.py > /opt/ingest/ingest.py
chmod 0755 /opt/ingest/ingest.py

cat > /etc/systemd/system/ingest.service <<EOF
[Unit]
Description=ingest (reenvío a la API de analítica)
After=network.target

[Service]
User=ingest
Environment=INGEST_API_TOKEN=$TOKEN
Environment=INGEST_BATCH=500
ExecStart=/usr/bin/python3 /opt/ingest/ingest.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now ingest
echo "Lab 35 plantado."
