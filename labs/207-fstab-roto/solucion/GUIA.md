# Resolución guiada · Lab 207

:::piensa Nunca reinicies para probar
Al arrancar, systemd monta todo lo que dice `/etc/fstab`. Si una línea falla
(y no lleva `nofail`), el arranque se para en *emergency mode*: una consola de
recuperación, sin red ni servicios. En una máquina remota eso es quedarte
fuera. `findmnt --verify` y `mount -a` dicen lo mismo que el arranque, sin
ningún riesgo.
:::

**El plan:** (1) diagnosticar, (2) arreglar cada línea y (3) comprobar sin
reiniciar.

## Paso 1 · Diagnóstico

:::pista Cómo hacerlo
```bash
sudo cp /etc/fstab /etc/fstab.bak
cat /etc/fstab
sudo findmnt --verify
sudo mount -a
lsblk -f
```
- Cada línea de `fstab` tiene seis campos: **qué** montar, **dónde**, **tipo**
  de sistema de ficheros, **opciones**, y dos números (`dump` y orden de
  `fsck`).
- `findmnt --verify` revisa el fichero entero y avisa de cada problema.
- `mount -a` intenta montar todo lo que aún no está montado, como haría el
  arranque.
- `lsblk -f` lista los discos con su tipo, etiqueta (`LABEL`) y `UUID`.

**Qué deberías ver:** tres problemas distintos, uno por línea.
:::

## Paso 2 · La línea de `/datos`

**Pregúntate:** `mount` no crea el punto de montaje. ¿Existe `/datos`?

:::pista Cómo hacerlo
```bash
ls -ld /datos
sudo mkdir -p /datos
```
:::

## Paso 3 · La línea de `/var/log/app`

:::pista Cómo hacerlo
Compara el tipo de la línea con el que dice `lsblk -f` para el disco `logs`:
la línea pone `ext44`, que no existe. Corrígelo a `ext4`:
```bash
sudo nano /etc/fstab
sudo mkdir -p /var/log/app
```
:::

## Paso 4 · La línea de `/backup`

**Pregúntate:** ¿ese UUID existe en esta máquina? Si el volumen no está
adjunto, ¿debe morir el arranque?

:::pista Cómo hacerlo
```bash
sudo blkid | grep 3f1c2d4e || echo "ese UUID no está"
```
`blkid` lista los sistemas de ficheros con su `UUID` y su etiqueta.

No está: es un volumen que no siempre se adjunta. Añade `nofail` a sus
opciones:
```
UUID=3f1c2d4e-…    /backup    ext4    defaults,nofail    0    2
```
`nofail` hace que un dispositivo ausente no sea fatal. Para acortar la espera
al arrancar, se suele añadir `x-systemd.device-timeout=5s`. En discos críticos
(los datos de la app) **no** uses `nofail`: mejor que el arranque se pare a
que la app arranque sin sus datos.
:::

## Paso 5 · Comprueba

```bash
sudo findmnt --verify
sudo mount -a && findmnt /datos /var/log/app
bash /opt/lab/check.sh
```
**Qué deberías ver:** `mount -a` sin errores, los dos montajes, y en
`findmnt --verify` sólo un aviso sobre `/backup` (el volumen no está; con
`nofail` es informativo).

## Cómo actuar en una situación así

- Copia de seguridad antes de editar (`/etc/fstab.bak`) y prueba siempre con
  `findmnt --verify` y `mount -a`.
- Usa `UUID=` o `LABEL=`, nunca `/dev/sdX` ni `/dev/loopN`: esos nombres
  dependen del orden en que se detectan los discos y cambian entre arranques.
- En una máquina en la nube con acceso sólo por consola, un fstab roto puede
  obligar a montar su disco raíz en otra instancia para arreglarlo.

## Si te atascas

- **`mount -a` dice `mount point does not exist`:** falta `mkdir -p`.
- **`unknown filesystem type 'ext44'`:** la errata del paso 3.
- **Para volver a empezar:** `sudo cp /etc/fstab.bak /etc/fstab`.
