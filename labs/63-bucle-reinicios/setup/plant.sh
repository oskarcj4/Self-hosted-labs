#!/usr/bin/env bash
# Lab 63: payments-worker en bucle de reinicios hasta agotar el límite de
# arranques. Dos causas encadenadas: EnvironmentFile con la ruta mal y el
# puerto ocupado por un servidor de depuración que alguien dejó encendido.
set -e
id payments >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin payments
install -m 0755 /opt/lab/setup/worker.py /usr/local/lib/payments_worker.py
mkdir -p /etc/payments
cat > /etc/payments/payments.env <<'EOF'
PAYMENTS_API_URL=https://pagos.interno/api/v3
PAYMENTS_API_TOKEN_FILE=/etc/payments/token
EOF
echo 'tok_live_9f3a2c71' > /etc/payments/token
chown -R root:payments /etc/payments && chmod 0750 /etc/payments && chmod 0640 /etc/payments/*

cat > /etc/systemd/system/payments-worker.service <<'EOF'
[Unit]
Description=payments-worker (cola de cobros)
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
User=payments
EnvironmentFile=/etc/payments/worker.env
ExecStart=/usr/bin/python3 /usr/local/lib/payments_worker.py
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

# Servidor de depuración "temporal" de hace dos semanas, en el puerto del worker.
systemd-run --unit=debug-9090 --description="debug temporal (INC-5870) BORRAR" \
  --property=User=nobody /usr/bin/python3 -m http.server 9090 --bind 127.0.0.1 --directory /tmp >/dev/null

systemctl daemon-reload
systemctl enable payments-worker >/dev/null 2>&1
systemctl start payments-worker || true
sleep 8   # agota StartLimitBurst: queda en 'failed'

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6303.txt <<'EOF'
INC-6303 · pay-01 · payments-worker
- La cola de cobros no avanza. payments-worker está "failed".
- El guardia hizo 'systemctl restart' tres veces: "arranca y se cae".
- Hace un mes se renombraron los ficheros de /etc/payments/ (worker.env -> payments.env).
- No metas el token ni la URL dentro de la unit: viven en /etc/payments/.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 63 plantado."
