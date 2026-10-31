#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
ss -tunap | grep 6667
PID=$(ss -tnp state established | grep '198.51.100.66:6667' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
lsof -i -P -n -p "$PID" || true
EXE=$(readlink /proc/$PID/exe)
UNIT=$(ps -o unit= -p "$PID")
mkdir -p /root/evidencia
cp /proc/$PID/exe /root/evidencia/dbus-sync.bin
cp /etc/systemd/system/$UNIT /root/evidencia/
cat > /home/analista/conexion.txt <<TXT
Destino: 198.51.100.66:6667 (ESTABLISHED)
PID: $PID   binario: $EXE   unidad: $UNIT (Restart=always)
TXT
chown analista:analista /home/analista/conexion.txt
iptables -I OUTPUT -d 198.51.100.66 -j REJECT
systemctl disable --now "$UNIT"
rm -f /etc/systemd/system/$UNIT
systemctl daemon-reload
rm -rf /var/tmp/.dbus
