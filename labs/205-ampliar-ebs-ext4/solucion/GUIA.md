# Resolución guiada · Lab 205

:::piensa Tres capas, un orden
Disco → partición → sistema de ficheros. Si saltas una capa, la de arriba no ve
el espacio nuevo. Mira primero **dónde** está el cuello de botella antes de
ejecutar nada.
:::

## Paso 1 · ¿Qué capa se quedó atrás?

**Pregúntate:** ¿cuánto mide el disco? ¿y la partición? ¿y el sistema de ficheros?

:::pista Cómo comprobarlo
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
df -h /datos
losetup -a
```
El disco (`loopN`) mide 800M; la partición (`loopNp1`) sigue en ~300M.
:::

## Paso 2 · Amplía la partición

:::pista Cómo hacerlo
```bash
sudo growpart /dev/loopN 1
```
`growpart` mueve el final de la partición 1 hasta el final del disco. No toca los datos.
:::

## Paso 3 · Avisa al kernel

**Pregúntate:** el kernel ya tiene cargada la partición con el tamaño viejo. ¿Cómo la refrescas sin desmontar?

:::pista Cómo hacerlo
```bash
sudo kpartx -u /dev/loopN
lsblk /dev/loopN
```
En EC2, `growpart` ya pide al kernel que relea la tabla (partx/udev).
:::

## Paso 4 · Amplía el ext4

:::pista Cómo hacerlo
```bash
sudo resize2fs /dev/mapper/loopNp1
df -h /datos
```
`resize2fs` crece ext4 montado (online). XFS usa `xfs_growfs /datos` (el punto de montaje, no el dispositivo).
:::

## Cómo actuar en una situación así

- **Snapshot antes** de tocar particiones.
- ext4 → `resize2fs <dispositivo>`; XFS → `xfs_growfs <montaje>`; si hay LVM, antes `pvresize` (lab 206).
- Si `df` no cambia, repite el diagnóstico capa por capa: `lsblk` te lo dice.
- AWS limita a un `modify-volume` cada 6 horas por volumen: planifica el tamaño.

## Si te atascas

- `growpart` dice `NOCHANGE`: la partición ya ocupa todo el disco; el problema está más arriba.
- `resize2fs` dice "Nothing to do": no refrescaste la partición (`kpartx -u`).
