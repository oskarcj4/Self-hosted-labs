# Solución — Ampliar un EBS con partición ext4

## Qué pasaba

El volumen EBS creció de 300 a 800 MiB, pero la partición 1 y el ext4 seguían con
el tamaño viejo: ampliar el volumen en AWS no amplía lo que hay dentro.

## Arreglo

```bash
lsblk
sudo growpart /dev/loopN 1        # loopN = disco que respalda /datos
sudo kpartx -u /dev/loopN
sudo resize2fs /dev/mapper/loopNp1
df -h /datos
bash /opt/lab/check.sh
```

## Más allá del lab

- En EC2 con NVMe: `sudo growpart /dev/nvme1n1 1 && sudo resize2fs /dev/nvme1n1p1` (XFS: `sudo xfs_growfs /datos`).
- Automatiza la ampliación con `cloud-init` (`growpart` + `resizefs`) para el volumen raíz.
