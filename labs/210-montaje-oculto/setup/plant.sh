#!/usr/bin/env bash
# Lab 210: df dice lleno, du dice vacío
set -e
export DM_DISABLE_UDEV=1
# Sin udev, el contenedor no crea /dev/loopN al vuelo: los preparamos.
for i in $(seq 0 127); do [ -b /dev/loop$i ] || mknod -m660 /dev/loop$i b 7 $i; done
/opt/lab/clean.sh || true          # restos de una ejecución anterior
D=/srv/disks; mkdir -p $D
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
truncate -s 100M $D/tc210-raiz.img
B=$(losetup -f --show $D/tc210-raiz.img)
mkfs.ext4 -q -m0 -L raiz $B
mkdir -p /almacen; mount $B /almacen
mkdir -p /almacen/datos /almacen/logs
# Subidas escritas ANTES de montar el disco de datos: quedan ocultas bajo el punto de montaje.
for i in 1 2 3 4 5; do dd if=/dev/urandom of=/almacen/datos/subida-2025-0$i.bin bs=1M count=5 status=none; done
( cd /almacen/datos && sha256sum subida-2025-*.bin ) > /opt/lab/hidden.sha256
truncate -s 120M $D/tc210-datos.img
A=$(losetup -f --show $D/tc210-datos.img)
mkfs.ext4 -q -L datos $A
mount $A /almacen/datos
dd if=/dev/urandom of=/almacen/datos/clientes.db bs=1M count=40 status=none
sha256sum /almacen/datos/clientes.db | cut -d' ' -f1 > /opt/lab/clientes.sha

# Un colector que "rota" borrando el log sin cerrarlo: el espacio no se libera.
cat > /opt/lab/colector.py <<'PY'
import os, time
f = open('/almacen/logs/colector.log', 'wb')
if not os.path.exists('/run/colector.ok'):
    f.write(os.urandom(1024) * (45 * 1024)); f.flush()
    open('/run/colector.ok', 'w').close()
os.unlink('/almacen/logs/colector.log')       # "rotación" mal hecha: borra pero sigue abierto
while True:
    time.sleep(3600)
PY
cat > /etc/systemd/system/colector.service <<'U'
[Unit]
Description=Colector de eventos
[Service]
ExecStart=/usr/bin/python3 /opt/lab/colector.py
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload; systemctl enable --now colector
sleep 3

cat > /home/analista/TAREA.txt <<'TXT'
SEC-210 · oculto-210
/almacen (disco "raiz", 100 MiB) está al ~75 %, pero:
   du -sh --exclude=datos /almacen   ->  casi nada
Hay dos causas distintas y las dos hacen que df y du no cuadren:

  A) alguien escribió ficheros en /almacen/datos ANTES de montar el disco de
     datos encima: siguen ahí, ocultos bajo el montaje.
  B) un servicio borró su log sin cerrarlo: el fichero ya no tiene nombre
     pero sigue ocupando espacio mientras el proceso lo tenga abierto.

Objetivo: dejar /almacen por debajo de 20 MiB usados sin perder datos:
  - los ficheros ocultos NO se borran: pertenecen al disco de datos
    (deben acabar dentro de él, ya montado)
  - el disco de datos sigue montado en /almacen/datos y clientes.db intacto
  - el servicio colector sigue vivo, pero sin el fichero borrado abierto
TXT
chown -R analista:analista /home/analista
echo "Lab 210 plantado."
