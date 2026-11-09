#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mdadm --detail /dev/md212 | grep -E 'State|Devices'
L=$(losetup -f --show $D/tc212-d3.img)
mdadm /dev/md212 --add $L
mdadm --wait /dev/md212 || true
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
cat /proc/mdstat
