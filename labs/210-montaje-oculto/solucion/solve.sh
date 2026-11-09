#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mkdir -p /mnt/vista
mount --bind /almacen /mnt/vista
ls -la /mnt/vista/datos
mv /mnt/vista/datos/subida-2025-*.bin /almacen/datos/
umount /mnt/vista
lsof -nP +L1 | head
systemctl restart colector
sleep 2
df -h /almacen
