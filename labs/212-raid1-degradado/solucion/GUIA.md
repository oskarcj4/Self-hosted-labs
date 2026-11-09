# Resolución guiada · Lab 212

:::piensa Menos redundancia, más urgencia
Mientras el array está degradado, un segundo fallo = pérdida total. El objetivo
es volver a `[UU]` lo antes posible, sin interrumpir el servicio.
:::

## Paso 1 · Lee el estado

:::pista Cómo comprobarlo
```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md212
```
`[2/1] [U_]` = dos esperados, uno presente. En `--detail` verás un hueco "removed".
:::

## Paso 2 · Presenta el disco y añádelo

**Pregúntate:** el reemplazo tiene que ser igual o mayor que el que falta. ¿Lo es?

:::pista Cómo hacerlo
```bash
sudo losetup -f --show /srv/disks/tc212-d3.img      # /dev/loopN
sudo mdadm /dev/md212 --add /dev/loopN
cat /proc/mdstat                                     # recovery = X%
```
:::

## Paso 3 · Espera

:::pista Cómo hacerlo
```bash
sudo mdadm --wait /dev/md212
cat /proc/mdstat                                     # [UU]
```
:::

## Paso 4 · Persistencia

:::pista Cómo hacerlo
```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
```
En Debian real, después `sudo update-initramfs -u` si el array es de arranque.
:::

## Cómo actuar en una situación así

- Alertas: `MAILADDR` en `mdadm.conf` + servicio `mdmonitor`.
- Antes de reemplazar, verifica la copia de seguridad: la reconstrucción castiga al disco que queda.
- RAID ≠ backup. RAID5 con discos grandes: riesgo alto durante la reconstrucción.

## Si te atascas

- "Cannot add: device too small": el reemplazo es más pequeño que el array.
- `--add` dice "busy": ese loop ya pertenece a otro array.
