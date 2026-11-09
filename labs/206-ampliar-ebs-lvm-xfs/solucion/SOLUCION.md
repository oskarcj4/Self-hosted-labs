# Solución — LVM + XFS

## Qué pasaba

El PV conservaba el tamaño antiguo (400M) y el volumen nuevo no estaba en el VG:
LVM no tenía espacio libre que dar al LV.

## Arreglo

```bash
sudo pvs
sudo pvresize /dev/loopN                                  # el que está en vg206
sudo losetup -f --show /srv/disks/tc206-xvdg.img          # → /dev/loopM
sudo pvcreate /dev/loopM
sudo vgextend vg206 /dev/loopM
sudo lvextend -r -l +100%FREE /dev/vg206/datos
df -h /datos
bash /opt/lab/check.sh
```

## Más allá del lab

- Con EBS reales: `pvresize /dev/nvme1n1`, `vgextend vg /dev/nvme2n1`, `lvextend -r`.
- Para ext4 con LVM el mismo `lvextend -r` llama a `resize2fs`.
