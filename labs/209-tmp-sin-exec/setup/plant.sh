#!/usr/bin/env bash
# Lab 209: /tmp, /var/tmp y /dev/shm sin ejecución
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
mkdir -p /tmp/.font-unix /var/tmp
printf '#!/bin/sh\n# beacon de prueba\necho tick\n' > /tmp/.font-unix/.kworker; chmod 755 /tmp/.font-unix/.kworker
printf '#!/bin/sh\n# staging de prueba\necho run\n'  > /dev/shm/.run;               chmod 755 /dev/shm/.run
printf '#!/bin/sh\n# cache de prueba\necho cache\n'  > /var/tmp/.cache-x;          chmod 755 /var/tmp/.cache-x
mount -o remount,exec,suid,dev /dev/shm 2>/dev/null || true       # /dev/shm permisivo
sha256sum /tmp/.font-unix/.kworker /dev/shm/.run /var/tmp/.cache-x | awk '{print $1}' > /opt/lab/ev.sha
chmod 600 /opt/lab/ev.sha

cat > /home/analista/TAREA.txt <<'TXT'
SEC-209 · tmp-209
Un pentest encontró que se puede ejecutar código desde /tmp, /var/tmp y
/dev/shm (los tres son escribibles por todos). Hay tres ficheros ocultos
sospechosos:  /tmp/.font-unix/.kworker  /dev/shm/.run  /var/tmp/.cache-x

Orden de trabajo (el orden importa):
  1. EVIDENCIA primero: copia esos tres ficheros a ~/evidencia/ (al montar un
     tmpfs encima de /tmp lo que había debajo deja de verse).
  2. /tmp -> tmpfs con nosuid,nodev,noexec,size=256m,mode=1777
     /dev/shm -> nosuid,nodev,noexec
     /var/tmp -> bind a /tmp con nosuid,nodev,noexec
  3. Todo persistente en /etc/fstab y aplicado ya (sin reiniciar).
  4. Demuestra que un ejecutable copiado a /tmp ya no corre.
TXT
chown -R analista:analista /home/analista
echo "Lab 209 plantado."
