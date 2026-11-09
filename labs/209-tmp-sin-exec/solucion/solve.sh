#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mkdir -p $H/evidencia
cp -p /tmp/.font-unix/.kworker /dev/shm/.run /var/tmp/.cache-x $H/evidencia/
chown -R analista:analista $H/evidencia
cat >> /etc/fstab <<'F'
tmpfs  /tmp      tmpfs  defaults,nosuid,nodev,noexec,size=256m,mode=1777  0 0
tmpfs  /dev/shm  tmpfs  defaults,nosuid,nodev,noexec,size=128m            0 0
/tmp   /var/tmp  none   bind,nosuid,nodev,noexec                          0 0
F
mount /tmp
mount -o remount,nosuid,nodev,noexec /dev/shm
mount /var/tmp
findmnt /tmp /var/tmp /dev/shm
