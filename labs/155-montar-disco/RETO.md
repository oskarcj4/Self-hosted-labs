# Montar un disco

> Almacenamiento · losetup · mkfs.ext4 · mount · /etc/fstab

## Escenario

Llegó un disco nuevo para los datos de la app. Aquí se representa como una
imagen de bloque sin formato en `/srv/disks/data.img` (256 MiB). Hay que
formatearlo, montarlo y dejarlo **persistente** para que sobreviva a un reinicio.

Flujo clásico de un disco en Linux:
1. Reconocer el dispositivo de bloque (`lsblk`, `losetup`).
2. Crear un sistema de ficheros (`mkfs.ext4`).
3. Montarlo en un directorio (`mount`).
4. Hacerlo persistente en `/etc/fstab`.

## Objetivos

1. Conecta la imagen como dispositivo loop:
   `sudo losetup -fP --show /srv/disks/data.img` → imprime `/dev/loopN`.
2. Formatéala en ext4: `sudo mkfs.ext4 /dev/loopN`.
3. Móntala en `/mnt/datos`.
4. Añade a `/etc/fstab` una entrada por **imagen** (opción `loop`) y verifica
   con `sudo mount -a` que funciona sin la línea escrita a mano.

## Pistas

```bash
lsblk
LOOP=$(sudo losetup -fP --show /srv/disks/data.img)
sudo mkfs.ext4 "$LOOP"
sudo mkdir -p /mnt/datos && sudo mount "$LOOP" /mnt/datos
# fstab por imagen (no por /dev/loopN, que cambia de número):
echo '/srv/disks/data.img  /mnt/datos  ext4  loop  0  0' | sudo tee -a /etc/fstab
sudo umount /mnt/datos && sudo mount -a && findmnt /mnt/datos
```

> En fstab apunta al **fichero de imagen** con la opción `loop`, no a
> `/dev/loopN`: el número de loop no es estable entre reinicios.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
