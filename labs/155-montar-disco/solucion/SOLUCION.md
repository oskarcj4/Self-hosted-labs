# Solución — Montar un disco

## Pasos

```bash
IMG=/srv/disks/data.img

# 1) Dispositivo de bloque desde la imagen
LOOP=$(sudo losetup -fP --show "$IMG")   # p. ej. /dev/loop0

# 2) Sistema de ficheros
sudo mkfs.ext4 "$LOOP"

# 3) Montar
sudo mkdir -p /mnt/datos
sudo mount "$LOOP" /mnt/datos

# 4) Persistencia (por imagen, opción loop)
echo "$IMG  /mnt/datos  ext4  loop  0  0" | sudo tee -a /etc/fstab
sudo umount /mnt/datos && sudo mount -a   # valida la línea de fstab
findmnt /mnt/datos
```

## Notas

- `losetup -fP`: `-f` busca el primer loop libre, `-P` crea particiones si la
  imagen las tuviera, `--show` imprime el dispositivo asignado.
- **fstab por imagen + `loop`**: el kernel crea el loop automáticamente al
  montar. Apuntar a `/dev/loop0` fallaría si el número cambia.
- Disco real (no imagen): el flujo es idéntico pero sobre `/dev/sdX`; puedes
  usar el UUID (`blkid`) en fstab en vez de la ruta del dispositivo.
- `umount` antes de `mount -a` prueba que la persistencia funciona de verdad y no
  por el montaje manual que ya tenías.

## Más allá del lab

- UUID en fstab: `UUID=$(sudo blkid -s UUID -o value /dev/loop0)` → más estable
  que la ruta.
- Opciones útiles: `noatime` (rendimiento), `nosuid,nodev,noexec` (seguridad en
  discos de solo datos).
- Para cifrado en reposo, ver el lab 156 (LUKS).
