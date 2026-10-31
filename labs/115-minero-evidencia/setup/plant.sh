#!/usr/bin/env bash
# Lab 115: un minero corre como www-data desde un directorio oculto de /tmp.
# Tras arrancar borra su propio binario: sólo queda en memoria (/proc/PID/exe).
set -e
D=/tmp/.X11-cache
mkdir -p $D
cp /bin/bash $D/kdevtmpfsi
sha256sum $D/kdevtmpfsi | cut -d' ' -f1 > /opt/lab/.ref-sha256
chmod 0600 /opt/lab/.ref-sha256
chown -R www-data:www-data $D
WALLET=4AxQ7mWz9fT3kLp2RcV8nB6yD1sH5gJ0uE4iO7aZ2xC9vN3mQ8wK
echo "$WALLET" > /opt/lab/.ref-wallet; chmod 0600 /opt/lab/.ref-wallet

for _ in $(seq 1 30); do getent hosts pool.minexmr.lab >/dev/null && break; sleep 1; done
systemd-run --unit=php-fpm-pool --description="PHP FastCGI pool" \
  -p User=www-data -p WorkingDirectory=$D -p StandardOutput=null -p StandardError=null \
  -p Nice=10 \
  --setenv=MINER_WALLET=$WALLET --setenv=MINER_THREADS=1 --setenv=HISTFILE=/dev/null \
  $D/kdevtmpfsi -c 'exec 3<>/dev/tcp/pool.minexmr.lab/3333; while :; do :; done' \
  kdevtmpfsi --url stratum+tcp://pool.minexmr.lab:3333 --user "$WALLET" --donate-level 1 >/dev/null
sleep 2
rm -f $D/kdevtmpfsi   # el binario se borra solo: queda sólo en memoria

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-115.txt <<'TXT'
INC-115 · web-115
Monitorización: CPU al 100 % desde esta mañana y la web va lenta.
Antes de matar NADA, guarda evidencia en ~/evidencia/ (forense la pedirá):
el binario, su línea de comando, su entorno, sus conexiones, su hash y una
foto de top. Después, detenlo.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 115 plantado."
