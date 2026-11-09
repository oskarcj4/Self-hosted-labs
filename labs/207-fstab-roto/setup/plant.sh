#!/usr/bin/env bash
# Lab 207: /etc/fstab roto antes de un reinicio
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
for n in datos logs; do
  truncate -s 64M $D/tc207-$n.img
  L=$(losetup -f --show $D/tc207-$n.img)
  mkfs.ext4 -q -L $n $L
  mkdir -p /tmp/p && mount $L /tmp/p && echo "sentinel-$n" > /tmp/p/ok.txt && umount /tmp/p
done
mkdir -p /var/log/app
cat > /etc/fstab <<'F'
# <file system>                              <mount point>  <type>  <options>   <dump> <pass>
LABEL=datos                                  /datos         ext4    defaults    0      2
LABEL=logs                                   /var/log/app   ext44   defaults    0      2
UUID=3f1c2d4e-9a7b-4c1d-8e2f-5a6b7c8d9e0f    /backup        ext4    defaults    0      2
F

cat > /home/analista/TAREA.txt <<'TXT'
SEC-207 · fstab-207
Mañana hay reinicio de mantenimiento. Un compañero tocó /etc/fstab y el último
reinicio de staging acabó en "emergency mode".

Deja /etc/fstab listo:
  - findmnt --verify sin errores
  - sudo mount -a debe montar /datos (LABEL=datos) y /var/log/app (LABEL=logs)
  - el volumen /backup (un EBS que a veces NO está adjunto) no puede impedir
    el arranque si falta: nofail

Pista: no uses /dev/loopN en fstab (cambia en cada arranque): etiquetas o UUID.
TXT
chown -R analista:analista /home/analista
echo "Lab 207 plantado."
