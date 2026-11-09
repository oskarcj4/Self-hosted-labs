#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mkdir -p /datos /var/log/app
sed -i 's/ ext44 / ext4 /' /etc/fstab
sed -i '/\/backup/ s/defaults/defaults,nofail/' /etc/fstab
findmnt --verify --tab-file /etc/fstab || true
mount -a
findmnt /datos /var/log/app
