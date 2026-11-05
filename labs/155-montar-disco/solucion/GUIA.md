# Resolución guiada · Lab 155

:::piensa Cuatro pasos de todo disco
Reconocer → formatear → montar → persistir. Saltarte el cuarto significa que el
disco desaparece en el siguiente reinicio.
:::

## Paso 1 · Dispositivo de bloque

:::pista Cómo hacerlo
```bash
lsblk
LOOP=$(sudo losetup -fP --show /srv/disks/data.img)
echo "$LOOP"
```
`losetup -f` elige el primer loop libre; `--show` te dice cuál.
:::

## Paso 2 · Formatear y montar

:::pista Cómo hacerlo
```bash
sudo mkfs.ext4 "$LOOP"
sudo mkdir -p /mnt/datos
sudo mount "$LOOP" /mnt/datos
findmnt /mnt/datos
```
:::

## Paso 3 · Persistencia en fstab

**Pregúntate:** ¿qué pasa con `/dev/loop0` tras un reinicio? El número puede
cambiar. Por eso en fstab se apunta al fichero.

:::pista Cómo hacerlo
```bash
echo '/srv/disks/data.img  /mnt/datos  ext4  loop  0  0' | sudo tee -a /etc/fstab
sudo umount /mnt/datos && sudo mount -a && mountpoint /mnt/datos
```
:::

## Cómo actuar en una situación así

- Siempre valida fstab con `umount` + `mount -a` ANTES de reiniciar. Una línea
  mala en fstab puede dejar el arranque colgado.
- En discos reales, usa UUID (`blkid`) en vez de rutas de dispositivo.

## Si te atascas

- `losetup` no imprime nada: añade `--show`.
- `mount -a` no monta: revisa la sintaxis de la línea en `/etc/fstab`
  (6 campos, separados por espacios).
