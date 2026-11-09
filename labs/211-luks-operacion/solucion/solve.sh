#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export DM_DISABLE_UDEV=1
H=/home/analista
D=/srv/disks
loopof(){ losetup -a | grep "/$1" | head -1 | cut -d: -f1; }
IMG=$D/tc211-boveda.img
S=/root/sobre/boveda.key
cryptsetup open $IMG boveda --key-file $S
mkdir -p /boveda /etc/luks
mount /dev/mapper/boveda /boveda
head -c 64 /dev/urandom > /etc/luks/boveda.key; chmod 400 /etc/luks/boveda.key
cryptsetup luksAddKey --pbkdf pbkdf2 --pbkdf-force-iterations 1000 --key-file $S $IMG /etc/luks/boveda.key
printf %s 'Verano2023' | cryptsetup luksRemoveKey $IMG --key-file -
cryptsetup luksHeaderBackup $IMG --header-backup-file $H/boveda.header
chmod 600 $H/boveda.header; chown analista:analista $H/boveda.header
echo "boveda  $IMG  /etc/luks/boveda.key  luks,nofail" >> /etc/crypttab
echo "/dev/mapper/boveda  /boveda  ext4  defaults,nofail  0  2" >> /etc/fstab
cryptsetup luksDump $IMG | grep -E 'Keyslots|^  [0-9]+: luks2'
