#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
A=$(loopof tc206-xvdf)
pvresize $A
B=$(losetup -f --show $D/tc206-xvdg.img)
pvcreate -q $B
vgextend vg206 $B
lvextend -r -l +100%FREE /dev/vg206/datos
df -h /datos
