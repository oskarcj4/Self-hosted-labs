#!/usr/bin/env bash
# Lab 212: RAID1 degradado: sustituir un disco fallido
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mdadm --stop /dev/md212 >/dev/null 2>&1 || true
for n in d1 d2 d3; do truncate -s 64M $D/tc212-$n.img; done
LA=$(losetup -f --show $D/tc212-d1.img); LB=$(losetup -f --show $D/tc212-d2.img)
mdadm --create /dev/md212 --run --level=1 --raid-devices=2 --metadata=1.2 --name=raid-212:212 $LA $LB
sleep 1
[ -b /dev/md212 ] || mknod /dev/md212 b $(sed 's/:/ /' /sys/block/md212/dev)
mdadm --wait /dev/md212 || true
mkfs.ext4 -q -L raid /dev/md212
mkdir -p /datos; mount /dev/md212 /datos
mkdir -p /datos/contabilidad
for i in 1 2 3 4; do dd if=/dev/urandom of=/datos/contabilidad/libro$i.dat bs=1M count=5 status=none; done
( cd /datos && sha256sum contabilidad/*.dat ) > /opt/lab/manifest.sha256
sync
# El segundo disco muere.
mdadm /dev/md212 --fail $LB >/dev/null
mdadm /dev/md212 --remove $LB >/dev/null
losetup -d $LB; rm -f $D/tc212-d2.img
echo "escrito con el array degradado" > /datos/contabilidad/nota.txt
( cd /datos && sha256sum contabilidad/*.dat contabilidad/nota.txt ) > /opt/lab/manifest.sha256
sync

cat > /home/analista/TAREA.txt <<'TXT'
SEC-212 · raid-212
Salta la alerta: /dev/md212 (RAID1) está degradado. Un disco murió y se
retiró. En /srv/disks/tc212-d3.img hay un disco de reemplazo (64 MiB, vacío).

  1. Diagnóstico: cat /proc/mdstat ; mdadm --detail /dev/md212
  2. Presenta el disco nuevo como dispositivo y añádelo al array.
  3. Espera a que termine la reconstrucción (mdadm --wait / mdstat).
  4. Haz persistente el array en /etc/mdadm/mdadm.conf (si no, tras reiniciar
     puede aparecer como md127 o no ensamblarse).
Los datos de /datos deben seguir accesibles y sin cambios durante todo el proceso.
TXT
chown -R analista:analista /home/analista
echo "Lab 212 plantado."
