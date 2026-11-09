#!/usr/bin/env bash
# Lab 208: Disco externo montado sin restricciones
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
truncate -s 64M $D/tc208-usb.img
L=$(losetup -f --show $D/tc208-usb.img)
mkfs.ext4 -q -L PENDRIVE $L
mkdir -p /media/usb; mount $L /media/usb          # opciones por defecto: suid,dev,exec
cd /media/usb
mkdir -p facturas; echo "Factura 0001 - 1200 EUR" > facturas/0001.txt
cp /bin/bash .mantenimiento; chown root:root .mantenimiento; chmod 4755 .mantenimiento   # SUID root
mknod sda1 b 7 0; chmod 666 sda1                                                          # nodo de dispositivo
cat > autorun.sh <<'S'
#!/bin/sh
# "Utilidad" del proveedor
echo "instalando..."
S
chmod 755 autorun.sh
sync
cat > /home/analista/TAREA.txt <<'TXT'
SEC-208 · usb-208
Un proveedor dejó un disco USB en el servidor y alguien lo montó en /media/usb
con las opciones por defecto (suid,dev,exec).

Hay que:
  1. Inventariar lo peligroso que trae el disco (ficheros SUID, nodos de
     dispositivo, ejecutables) -> ~/hallazgos.txt (una ruta por línea).
     NO borres nada: es evidencia.
  2. Contenerlo: remonta /media/usb con nosuid,nodev,noexec.
  3. Deja la regla en /etc/fstab (LABEL=PENDRIVE) para que cualquier montaje
     futuro lleve esas opciones y no bloquee el arranque si no está (nofail).
  4. Demuestra que ya no sirve: el binario SUID debe dejar de ejecutarse.
TXT
chown -R analista:analista /home/analista
echo "Lab 208 plantado."
