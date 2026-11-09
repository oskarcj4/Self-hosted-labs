#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
M=/media/usb
{ find $M -xdev -type f \( -perm -4000 -o -perm -2000 \) ; find $M -xdev \( -type b -o -type c \) ; find $M -xdev -type f -perm -u+x ! -perm -4000; } | sort -u > $H/hallazgos.txt
chown analista:analista $H/hallazgos.txt
mount -o remount,nosuid,nodev,noexec $M
grep -q '/media/usb' /etc/fstab || echo 'LABEL=PENDRIVE  /media/usb  ext4  nosuid,nodev,noexec,nofail  0  0' >> /etc/fstab
findmnt $M
