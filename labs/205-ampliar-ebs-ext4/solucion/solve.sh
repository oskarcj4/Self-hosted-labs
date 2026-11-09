#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
L=$(loopof tc205-xvdf); N=$(basename $L)
growpart $L 1
kpartx -u $L
resize2fs /dev/mapper/${N}p1
df -h /datos
