# Ampliar un EBS con partición ext4

> AWS · EBS · growpart · resize2fs · disco → partición → sistema de ficheros

## Escenario

`/datos` (ext4, en una partición de un volumen EBS) está al 70 %. Ayer se
amplió el volumen en la consola de AWS (`modify-volume`), pero `df -h` sigue
mostrando el tamaño de antes. Ampliar un volumen en AWS **no** amplía lo que
hay dentro: hay que crecer tres capas, en orden.

1. El **disco** (lo hizo AWS).
2. La **partición** (`growpart`).
3. El **sistema de ficheros** (`resize2fs` para ext4, `xfs_growfs` para XFS).

En el contenedor no hay udev, así que tras `growpart` hay que avisar a mano
al kernel de la partición nueva con `kpartx -u` (en EC2 lo hace `partx`/udev).

## Objetivos

1. Ve la diferencia entre el tamaño del disco, el de la partición y el de `df`.
2. Amplía la partición para ocupar todo el disco.
3. Amplía el ext4 **en caliente** (sin desmontar `/datos`).
4. Comprueba que no se perdió ningún informe y que quedan > 500 MiB libres.

## Comandos que te pueden servir

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
df -h /datos
sudo growpart /dev/loopN 1            # amplía la partición 1 del disco
sudo kpartx -u /dev/loopN             # refresca el mapeo de particiones
sudo resize2fs /dev/mapper/loopNp1    # ext4: amplía al tamaño de la partición
```

> Antes de tocar nada en producción: **snapshot del volumen**. Ampliar es
> seguro, pero un error en la tabla de particiones no tiene vuelta atrás. Y un
> EBS no se puede reducir.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
