# Solución — operar una bóveda LUKS

## Arreglo

```bash
IMG=/srv/disks/tc211-boveda.img
sudo cryptsetup open $IMG boveda --key-file /root/sobre/boveda.key
sudo mkdir -p /boveda /etc/luks && sudo mount /dev/mapper/boveda /boveda
sudo sh -c 'head -c 64 /dev/urandom > /etc/luks/boveda.key && chmod 400 /etc/luks/boveda.key'
sudo cryptsetup luksAddKey $IMG /etc/luks/boveda.key --key-file /root/sobre/boveda.key
printf %s Verano2023 | sudo cryptsetup luksRemoveKey $IMG --key-file -
sudo cryptsetup luksHeaderBackup $IMG --header-backup-file ~/boveda.header
sudo chown analista: ~/boveda.header; chmod 600 ~/boveda.header
echo "boveda  $IMG  /etc/luks/boveda.key  luks,nofail" | sudo tee -a /etc/crypttab
echo '/dev/mapper/boveda  /boveda  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
bash /opt/lab/check.sh
```

## Más allá del lab

- `systemd-cryptenroll` con TPM2/FIDO2; `clevis` + `tang` para desbloqueo en red.
- `cryptsetup luksHeaderRestore` recupera una bóveda con cabecera dañada.
