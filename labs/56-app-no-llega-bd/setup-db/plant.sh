#!/usr/bin/env bash
# db-01 (lab 56): la BD escucha sólo en loopback y el firewall sigue
# permitiendo la IP que tenía app-01 antes de la migración de red.
set -e
id minidb >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin minidb
id dba >/dev/null 2>&1 || useradd -m -s /bin/bash dba
echo 'dba:Guardia-2026' | chpasswd
echo 'dba ALL=(ALL) ALL' > /etc/sudoers.d/dba && chmod 0440 /etc/sudoers.d/dba

install -m 0755 /opt/node/minidb.py /usr/local/lib/minidb.py
install -m 0755 /opt/node/agent.py /usr/local/lib/state-agent.py
mkdir -p /etc/minidb
cat > /etc/minidb/minidb.conf <<'EOF'
# minidb — configuración del servidor
# Dirección en la que escucha. 127.0.0.1 = sólo conexiones locales.
listen_address = 127.0.0.1
port = 5432
EOF

cat > /etc/systemd/system/minidb.service <<'EOF'
[Unit]
Description=minidb (base de datos de pedidos)
After=network.target firewall.service

[Service]
User=minidb
ExecStart=/usr/bin/python3 /usr/local/lib/minidb.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/state-agent.service <<'EOF'
[Unit]
Description=Agente de inventario (CMDB, sólo lectura)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/state-agent.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/iptables
cat > /etc/iptables/rules.v4 <<'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 9100 -j ACCEPT
# app-01 -> minidb
-A INPUT -s 10.76.56.99/32 -p tcp --dport 5432 -j ACCEPT
COMMIT
EOF
cat > /etc/systemd/system/firewall.service <<'EOF'
[Unit]
Description=Firewall (iptables-restore de /etc/iptables/rules.v4)
Before=network-online.target minidb.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now firewall minidb state-agent ssh
echo "db-01 plantado."
