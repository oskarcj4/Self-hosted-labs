#!/usr/bin/env bash
# Lab 205: Ampliar un EBS con partición ext4
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
truncate -s 300M $D/tc205-xvdf.img
L=$(losetup -fP --show $D/tc205-xvdf.img)
parted -s $L mklabel gpt mkpart datos ext4 1MiB 100%
kpartx -a $L; N=$(basename $L)
mkfs.ext4 -q -L datos /dev/mapper/${N}p1
mkdir -p /datos; mount /dev/mapper/${N}p1 /datos
mkdir -p /datos/informes
for i in $(seq 1 18); do dd if=/dev/urandom of=/datos/informes/q$i.dat bs=1M count=10 status=none; done
( cd /datos && sha256sum informes/*.dat ) > /opt/lab/manifest.sha256
sync
# "Consola de AWS: modify-volume 300 GiB -> 800 GiB". El disco crece; nada más.
truncate -s 800M $D/tc205-xvdf.img
losetup -c $L

cat > /home/analista/TAREA.txt <<'TXT'
SEC-205 · ebs-205
/datos (ext4) está al 70 % y el equipo de finanzas sigue generando informes.
Ayer ampliaron el volumen EBS en la consola de AWS (modify-volume).
El disco ya mide más, pero df sigue enseñando lo de antes.

Amplía la partición y el sistema de ficheros EN CALIENTE (sin desmontar /datos
y sin perder ni un informe). Después de ampliar tienen que quedar > 500 MiB libres.

En un EC2 real el disco sería /dev/nvme1n1 (o /dev/xvdf) y la partición
/dev/nvme1n1p1. Aquí el "EBS" es un loop: mira lsblk. Como el contenedor no
tiene udev, las particiones aparecen como /dev/mapper/loopNp1 (kpartx).
TXT
chown -R analista:analista /home/analista
echo "Lab 205 plantado."
