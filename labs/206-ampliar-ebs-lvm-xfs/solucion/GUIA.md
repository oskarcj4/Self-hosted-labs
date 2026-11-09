# Resolución guiada · Lab 206

:::piensa Antes de ampliar
Hay dos orígenes de espacio nuevo: un disco que **creció** y un disco que **llegó**.
Se tratan distinto: el primero se "re-mide" (`pvresize`), el segundo se "añade" (`vgextend`).
:::

## Paso 1 · Estado actual

:::pista Cómo comprobarlo
```bash
sudo pvs; sudo vgs; sudo lvs
sudo losetup -a
df -h /datos
```
El PV mide 400M aunque el disco ya tiene 600M. El VG no tiene espacio libre.
:::

## Paso 2 · El disco que creció

**Pregúntate:** ¿qué capa de LVM guarda "el tamaño del disco"? ¿Cómo la actualizas?

:::pista Cómo hacerlo
```bash
sudo pvresize /dev/loopN     # el loop que ya pertenece a vg206
sudo vgs                     # ahora VFree ≈ 200M
```
:::

## Paso 3 · El disco nuevo

:::pista Cómo hacerlo
```bash
sudo losetup -f --show /srv/disks/tc206-xvdg.img
sudo pvcreate /dev/loopM
sudo vgextend vg206 /dev/loopM
sudo vgs                     # VFree ≈ 500M
```
:::

## Paso 4 · El LV y el XFS

:::pista Cómo hacerlo
```bash
sudo lvextend -r -l +100%FREE /dev/vg206/datos
df -h /datos
```
`-r` (`--resizefs`) llama a `xfs_growfs` por ti. Sin `-r`: `sudo xfs_growfs /datos` (el montaje, no el dispositivo).
:::

## Cómo actuar en una situación así

- LVM te deja crecer sin parar nada: es la razón de usarlo sobre EBS.
- Para reducir hay que cambiar de herramienta: ext4 sí reduce (desmontado); **XFS no**.
- Mejor ampliar el EBS existente que acumular muchos volúmenes pequeños.

## Si te atascas

- `lvextend` dice "insufficient free space": faltó `pvresize` o `vgextend`.
- `pvcreate` dice "device is partitioned" o "excluded": estás usando el loop equivocado (`losetup -a`).
