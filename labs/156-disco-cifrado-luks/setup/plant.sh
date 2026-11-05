#!/usr/bin/env bash
# Lab 156: datos sensibles que deben ir cifrados en reposo. Llega un disco
# (imagen loop) sin cifrar. El alumno lo cifra con LUKS (cryptsetup luksFormat),
# lo abre, formatea, monta y escribe los datos.
set -e
install -d -m 0700 /srv/secure
# "Disco" de 320 MiB (LUKS2 reserva cabecera; >64 MiB para holgura).
dd if=/dev/zero of=/srv/secure/vault.img bs=1M count=320 status=none

# Frase de cifrado entregada por el equipo (en un fichero, modo laboratorio).
install -d -m 0700 /etc/allsafe
printf '%s' 'fsociety-luks-2026' > /etc/allsafe/luks.key
chmod 600 /etc/allsafe/luks.key

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Disco cifrado con LUKS (cifrado en reposo)

Los datos sensibles deben ir en un volumen CIFRADO. Llega un disco sin cifrar en
/srv/secure/vault.img (320 MiB). La frase de cifrado está en /etc/allsafe/luks.key.

1. Conéctalo como dispositivo de bloque:
     LOOP=$(sudo losetup -fP --show /srv/secure/vault.img)
2. Cífralo con LUKS (esto DESTRUYE lo que hubiera: el disco viene vacío):
     sudo cryptsetup luksFormat --type luks2 "$LOOP" /etc/allsafe/luks.key
3. Ábrelo (crea /dev/mapper/vault):
     sudo cryptsetup luksOpen "$LOOP" vault --key-file /etc/allsafe/luks.key
4. Formatea y monta el dispositivo YA DESCIFRADO (el mapper, no el loop):
     sudo mkfs.ext4 /dev/mapper/vault
     sudo mkdir -p /mnt/vault
     sudo mount /dev/mapper/vault /mnt/vault
5. Escribe los datos sensibles, p. ej.:
     echo "clientes" | sudo tee /mnt/vault/datos.txt

Verifica que es LUKS:
     sudo cryptsetup isLuks "$LOOP" && echo "es LUKS"
     sudo cryptsetup luksDump "$LOOP" | head

Comprueba:  bash /opt/lab/check.sh
TXT
chown -R analista:analista /home/analista
echo "Lab 156 plantado."
