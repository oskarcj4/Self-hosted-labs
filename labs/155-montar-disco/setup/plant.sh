#!/usr/bin/env bash
# Lab 155: llega un "disco nuevo" (fichero de imagen respaldado por loop) sin
# formatear ni montar. El alumno lo formatea, lo monta y lo deja persistente.
set -e
install -d -m 0755 /srv/disks
# "Disco" de 256 MiB sin formato.
dd if=/dev/zero of=/srv/disks/data.img bs=1M count=256 status=none

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Montar un disco nuevo

Llegó un disco nuevo para los datos de la app. Está como imagen sin formato en
/srv/disks/data.img (256 MiB). Hay que ponerlo en marcha.

1. Conéctalo como dispositivo de bloque (loop):
     sudo losetup -fP --show /srv/disks/data.img     # imprime /dev/loopN
2. Formatéalo en ext4:
     sudo mkfs.ext4 /dev/loopN
3. Móntalo en /mnt/datos:
     sudo mkdir -p /mnt/datos
     sudo mount /dev/loopN /mnt/datos
4. Déjalo persistente en /etc/fstab (para que sobreviva a un reinicio). Para una
   imagen se usa la opción 'loop', apuntando al fichero, no al /dev/loopN:
     /srv/disks/data.img  /mnt/datos  ext4  loop  0  0
   Comprueba que la línea funciona:
     sudo umount /mnt/datos && sudo mount -a && mountpoint /mnt/datos

Útiles:  lsblk, findmnt /mnt/datos, losetup -a, df -h /mnt/datos

Comprueba:  bash /opt/lab/check.sh
TXT
chown -R analista:analista /home/analista
echo "Lab 155 plantado."
