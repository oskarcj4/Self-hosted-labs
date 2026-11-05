#!/usr/bin/env bash
# Solución automática (corre como analista; sudo donde haga falta).
set -e
IMG=/srv/disks/data.img

# 1) Conectar como dispositivo de bloque (loop)
LOOP=$(sudo losetup -fP --show "$IMG")
echo "loop = $LOOP"

# 2) Formatear ext4
sudo mkfs.ext4 -q "$LOOP"

# 3) Montar
sudo mkdir -p /mnt/datos
sudo mount "$LOOP" /mnt/datos

# 4) Persistencia en fstab (por imagen, opción loop) y prueba con mount -a
if ! grep -qE '\s/mnt/datos\s' /etc/fstab; then
  echo "$IMG  /mnt/datos  ext4  loop  0  0" | sudo tee -a /etc/fstab >/dev/null
fi
sudo umount /mnt/datos
sudo losetup -d "$LOOP" 2>/dev/null || true
sudo mount -a
findmnt /mnt/datos
echo "solve.sh completado."
