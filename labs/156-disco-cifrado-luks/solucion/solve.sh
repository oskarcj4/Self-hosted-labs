#!/usr/bin/env bash
# Solución automática (corre como analista; sudo donde haga falta).
set -e
IMG=/srv/secure/vault.img
KEY=/etc/allsafe/luks.key

# 1) Dispositivo de bloque
LOOP=$(sudo losetup -fP --show "$IMG")
echo "loop = $LOOP"

# 2) Cifrar con LUKS2
sudo cryptsetup luksFormat --type luks2 --batch-mode "$LOOP" "$KEY"

# 3) Abrir (mapper)
sudo cryptsetup luksOpen "$LOOP" vault --key-file "$KEY"

# 4) Formatear y montar el dispositivo descifrado
sudo mkfs.ext4 -q /dev/mapper/vault
sudo mkdir -p /mnt/vault
sudo mount /dev/mapper/vault /mnt/vault

# 5) Escribir datos sensibles
echo "clientes" | sudo tee /mnt/vault/datos.txt >/dev/null

echo "--- isLuks ---"; sudo cryptsetup isLuks "$LOOP" && echo "es LUKS"
echo "--- mapper ---"; sudo dmsetup ls --target crypt
findmnt /mnt/vault
echo "solve.sh completado."
