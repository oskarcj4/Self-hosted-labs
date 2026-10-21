#!/usr/bin/env bash
# Lab 56 (app-01): tras una migración de red, orders-app no llega a la BD.
# Falla en tres capas a la vez: nombre (hosts), firewall y bind en db-01.
set -e
id orders >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin orders
install -m 0755 /opt/lab/setup/orders_app.py /usr/local/lib/orders_app.py
cat > /etc/systemd/system/orders-app.service <<'EOF'
[Unit]
Description=orders-app (frontal de pedidos)
After=network.target

[Service]
User=orders
ExecStart=/usr/bin/python3 /usr/local/lib/orders_app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now orders-app

# Entrada estática de antes de la migración (la IP vieja de db-01).
grep -q 'db.interno' /etc/hosts || printf '\n# BD de pedidos\n10.76.56.99\tdb.interno\n' >> /etc/hosts

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-4120.txt <<'EOF'
INC-4120 · Prioridad 1 · app-01 -> db-01
- Anoche se migró la red interna a 10.76.56.0/24.
    app-01: 10.76.56.10      db-01: 10.76.56.20
- Desde entonces orders-app devuelve 503 (curl http://127.0.0.1:8080/health).
- "En db-01 la BD está arriba, lo he mirado" (equipo de datos).
- Acceso a db-01:  ssh dba@db-01   (contraseña: Guardia-2026, tiene sudo)
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 56 plantado."
