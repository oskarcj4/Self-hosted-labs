#!/usr/bin/env bash
# Lab 206: Más espacio con LVM y XFS (EBS ampliado + EBS nuevo)
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
truncate -s 400M $D/tc206-xvdf.img
L=$(losetup -f --show $D/tc206-xvdf.img)
pvcreate -q $L; vgcreate -q vg206 $L; lvcreate -q -n datos -l 100%FREE vg206
mkfs.xfs -q -L datos /dev/vg206/datos
mkdir -p /datos; mount /dev/vg206/datos /datos
mkdir -p /datos/dumps
for i in $(seq 1 15); do dd if=/dev/urandom of=/datos/dumps/d$i.dat bs=1M count=10 status=none; done
( cd /datos && sha256sum dumps/*.dat ) > /opt/lab/manifest.sha256
sync
# Consola de AWS: el volumen /dev/xvdf crece de 400 a 600 MiB...
truncate -s 600M $D/tc206-xvdf.img
losetup -c $L
# ...y se adjunta un segundo volumen /dev/xvdg de 300 MiB (existe, pero no está en uso).
truncate -s 300M $D/tc206-xvdg.img

cat > /home/analista/TAREA.txt <<'TXT'
SEC-206 · lvm-206
/datos (XFS sobre LVM, VG vg206) se llena. Se hicieron dos cambios en AWS:
  - el volumen /dev/xvdf (el que ya forma parte del VG) pasó de 400 a 600 MiB
  - se adjuntó un volumen nuevo /dev/xvdg de 300 MiB: /srv/disks/tc206-xvdg.img
    (hay que presentarlo como dispositivo con losetup)

Deja que /datos use TODO el espacio (≈ 890 MiB), en caliente y sin recrear nada.
XFS no se puede reducir: no te equivoques de dirección. Nada de mkfs.
TXT
chown -R analista:analista /home/analista
echo "Lab 206 plantado."
