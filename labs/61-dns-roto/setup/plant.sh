#!/usr/bin/env bash
# Lab 61 (app-03): la resolución de nombres está rota en tres sitios:
# resolv.conf apunta a un DNS dado de baja, falta el dominio de búsqueda y
# nsswitch.conf no consulta el DNS.
set -e
id checkout >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin checkout
install -m 0755 /opt/lab/setup/checkout.py /usr/local/lib/checkout.py
cat > /etc/systemd/system/checkout.service <<'EOF'
[Unit]
Description=checkout (frontal de pago)
After=network.target

[Service]
User=checkout
ExecStart=/usr/bin/python3 /usr/local/lib/checkout.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now checkout

# resolv.conf es un bind mount de Docker: se reescribe su contenido en el sitio.
cat > /etc/resolv.conf <<'EOF'
# Generado por el antiguo script de aprovisionamiento (ns-old, retirado en septiembre)
nameserver 10.76.61.250
options timeout:2 attempts:2
EOF

# "Hardening" de un compañero: sólo /etc/hosts, "que el DNS es inseguro".
sed -i 's/^hosts:.*/hosts:          files/' /etc/nsswitch.conf

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6101.txt <<'EOF'
INC-6101 · app-03 · checkout
- checkout no puede llamar a la API de pagos: /health da 503.
- La config de checkout usa el nombre corto "pagos" (en la zona "interno").
- DNS interno vigente: dns-01  10.76.61.53  (zona: interno)
- Alguien propuso "ponerlo en /etc/hosts y listo". NO: las IPs de pagos
  cambian en cada despliegue; el DNS es la fuente de verdad.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 61 plantado."
