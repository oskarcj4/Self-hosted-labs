# RAID1 degradado: sustituir un disco fallido

> mdadm · RAID1 · /proc/mdstat · --add · mdadm.conf

## Escenario

Salta la alerta en `raid-212`: el RAID1 `/dev/md212` (que guarda la
contabilidad en `/datos`) está **degradado**. Un disco murió y alguien lo
retiró del array. Mientras tanto, el servicio siguió escribiendo (`nota.txt`):
un RAID1 degradado funciona, pero con **una sola copia** de tus datos.

En `/srv/disks/tc212-d3.img` hay un disco de reemplazo vacío de 64 MiB.

## Objetivos

1. Diagnostica: qué disco falta y en qué estado está el array.
2. Presenta el disco de reemplazo (`losetup`) y añádelo al array.
3. Espera a que la reconstrucción termine.
4. Haz persistente el array en `/etc/mdadm/mdadm.conf`.
5. Los datos de `/datos` no se desmontan ni cambian en todo el proceso.

## Comandos que te pueden servir

```bash
cat /proc/mdstat                       # [U_] = degradado, [UU] = sano
sudo mdadm --detail /dev/md212
sudo losetup -f --show /srv/disks/tc212-d3.img
sudo mdadm /dev/md212 --add /dev/loopN
sudo mdadm --wait /dev/md212           # espera a que termine la sincronización
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
```

> En un fallo real: `mdadm /dev/mdX --fail /dev/sdY --remove /dev/sdY`, cambiar
> el disco, copiar la tabla de particiones y `--add`. RAID **no** es copia de
> seguridad: replica borrados y corrupción al instante.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
