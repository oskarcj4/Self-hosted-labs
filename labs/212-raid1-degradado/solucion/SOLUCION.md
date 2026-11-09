# Solución — RAID1 degradado

## Qué pasaba

`/dev/md212` tenía un solo miembro (`[U_]`). Se escribió con una única copia.

## Arreglo

```bash
cat /proc/mdstat
L=$(sudo losetup -f --show /srv/disks/tc212-d3.img)
sudo mdadm /dev/md212 --add $L
sudo mdadm --wait /dev/md212
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
bash /opt/lab/check.sh
```

## Más allá del lab

- `mdadm --monitor` con correo, `smartctl` para anticipar el fallo del disco.
- LVM RAID (`lvconvert --type raid1`) o ZFS/Btrfs como alternativas con checksum.
