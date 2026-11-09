#!/usr/bin/env bash
# Lab 211: Bóveda LUKS: rotar claves y no perder la cabecera
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
IMG=$D/tc211-boveda.img
truncate -s 64M $IMG
printf %s 'Verano2023' > /root/.old
cryptsetup luksFormat --type luks2 --batch-mode --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --key-file /root/.old $IMG
mkdir -p /root/sobre
head -c 64 /dev/urandom > /root/sobre/boveda.key; chmod 400 /root/sobre/boveda.key
cryptsetup luksAddKey --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --key-file /root/.old $IMG /root/sobre/boveda.key
cryptsetup open $IMG boveda --key-file /root/sobre/boveda.key
mkfs.ext4 -q -L boveda /dev/mapper/boveda
mkdir -p /boveda; mount /dev/mapper/boveda /boveda
printf 'empleado;iban\nana;ES00-0000-0001\nluis;ES00-0000-0002\n' > /boveda/nominas.csv
sha256sum /boveda/nominas.csv | cut -d' ' -f1 > /opt/lab/nominas.sha
umount /boveda
cryptsetup close boveda
rm -f /root/.old

cat > /home/analista/TAREA.txt <<'TXT'
SEC-211 · luks-211
La bóveda de nóminas es un contenedor LUKS2: /srv/disks/tc211-boveda.img.
Marcos (que ya no trabaja aquí) la abría con la clave  Verano2023, y esa
clave acabó en un chat. Hay además un keyfile de emergencia en un sobre:
/root/sobre/boveda.key

Hay que operarla:
  1. Abre la bóveda con el keyfile del sobre (mapper: boveda) y móntala en /boveda.
  2. Crea una llave nueva para el equipo: /etc/luks/boveda.key (root, modo 0400,
     64 bytes aleatorios) y añádela como keyslot.
  3. REVOCA la clave filtrada: Verano2023 ya no debe abrir la bóveda.
  4. Haz copia de la CABECERA: ~/boveda.header (sin cabecera, los datos se pierden).
  5. Apertura automática: /etc/crypttab (con el keyfile del equipo) y
     /etc/fstab (/dev/mapper/boveda -> /boveda). Con nofail.
Si luksAddKey falla por memoria, añade:  --pbkdf pbkdf2
TXT
chown -R analista:analista /home/analista
echo "Lab 211 plantado."
