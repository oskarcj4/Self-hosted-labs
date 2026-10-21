#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
journalctl -u report-gen --no-pager | grep -m1 -i 'oom' > /home/analista/incidente/causa.txt
chown analista: /home/analista/incidente/causa.txt
sed -i 's/^BATCH_SIZE=.*/BATCH_SIZE=100000/' /etc/report-gen.conf
systemctl restart report-gen
sleep 3
