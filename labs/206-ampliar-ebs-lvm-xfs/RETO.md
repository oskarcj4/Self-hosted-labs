# Más espacio con LVM y XFS

> AWS · LVM · pvresize · vgextend · lvextend -r · XFS

## Escenario

`/datos` es un XFS sobre LVM (`vg206`/`datos`) y se está llenando. En AWS se
hicieron dos cosas:

- El volumen `/dev/xvdf`, que ya es un PV del VG, **creció** de 400 a 600 MiB.
- Se **adjuntó** un volumen nuevo `/dev/xvdg` (300 MiB): el fichero
  `/srv/disks/tc206-xvdg.img`. En un EC2 real aparecería solo; aquí lo presentas
  como dispositivo con `losetup`.

LVM ve capas: disco → PV → VG → LV → sistema de ficheros. Cada una se amplía
con su propia herramienta y **XFS sólo crece, nunca se reduce**.

## Objetivos

1. Haz que LVM vea el tamaño nuevo del PV ya existente (`pvresize`).
2. Presenta el volumen nuevo, conviértelo en PV y súmalo al VG (`vgextend`).
3. Amplía el LV con todo el espacio libre **y** el XFS a la vez (`lvextend -r`).
4. Demuestra que no se perdió ningún dump.

## Comandos que te pueden servir

```bash
sudo pvs; sudo vgs; sudo lvs
sudo losetup -a
sudo pvresize /dev/loopN
sudo losetup -f --show /srv/disks/tc206-xvdg.img
sudo pvcreate /dev/loopM && sudo vgextend vg206 /dev/loopM
sudo lvextend -r -l +100%FREE /dev/vg206/datos     # -r = también el sistema de ficheros
df -h /datos
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
