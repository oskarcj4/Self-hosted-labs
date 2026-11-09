# /etc/fstab roto antes de un reinicio

> fstab · findmnt --verify · mount -a · nofail · LABEL/UUID

## Escenario

Mañana hay reinicio de mantenimiento en `fstab-207`. Un compañero editó
`/etc/fstab` y el último reinicio de staging acabó en **emergency mode**: una
línea mala de fstab (de un volumen que no es el raíz) basta para que systemd
no llegue a `multi-user.target`.

Hay tres líneas y cada una falla de forma distinta. **Nunca** reinicies para
probar: se valida antes.

## Objetivos

1. Diagnostica con `findmnt --verify` y `mount -a` **antes** de reiniciar.
2. Haz que se monten `/datos` (`LABEL=datos`) y `/var/log/app` (`LABEL=logs`).
3. El volumen `/backup` (un EBS que no siempre está adjunto) no debe cortar el
   arranque si falta: `nofail`.
4. Nada de `/dev/loopN` en fstab: usa etiquetas o UUID.

## Comandos que te pueden servir

```bash
cat /etc/fstab
sudo findmnt --verify
sudo mount -a
lsblk -f                      # etiquetas y UUID
sudo blkid
man fstab                     # campos y opciones
```

> `findmnt --verify` seguirá avisando de `/backup` (no encuentra el volumen) aunque
> lleve `nofail`: es un aviso informativo, no el fallo de arranque.
> `nofail` hace que un dispositivo ausente no sea fatal; `x-systemd.device-timeout=5s`
> acorta la espera. Para discos críticos (raíz, datos de la app) **no** uses nofail.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
