#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
E=/home/analista/evidencia
mkdir -p $E
uptime > $E/uptime.txt; nproc >> $E/uptime.txt
top -b -n1 > $E/top.txt
ps aux --sort=-%cpu | head -5 > $E/ps.txt
PID=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2{print $1}')
ls -l /proc/$PID/exe > $E/exe.txt
cp /proc/$PID/exe $E/binario
tr '\0' ' ' < /proc/$PID/cmdline > $E/cmdline.txt
tr '\0' '\n' < /proc/$PID/environ > $E/environ.txt
ss -tnp | grep "pid=$PID" > $E/conexiones.txt
sha256sum $E/binario > $E/sha256.txt
chown -R analista:analista $E
UNIT=$(ps -o unit= -p $PID)
systemctl stop "$UNIT" || kill -9 $PID
rm -rf /tmp/.X11-cache
