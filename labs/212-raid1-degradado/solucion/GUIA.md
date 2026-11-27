# Resolución guiada · Lab 212

:::piensa Menos redundancia, más urgencia
Un RAID1 guarda la misma información en dos discos. Mientras está
**degradado** (con uno solo), funciona con normalidad, pero un segundo fallo
significa perder todo. El objetivo es volver a tener dos copias cuanto antes,
sin interrumpir el servicio. Y recuerda: RAID no es una copia de seguridad,
porque replica al instante también los borrados y la corrupción.
:::

**El plan:** (1) leer el estado, (2) presentar el disco nuevo y añadirlo,
(3) esperar a la reconstrucción y (4) hacerlo persistente.

## Paso 1 · Lee el estado

:::pista Cómo hacerlo
```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md212
df -h /datos
```
- `/proc/mdstat` es el resumen del kernel de todos los RAID por software.
- `mdadm --detail` da el detalle de uno: estado, discos esperados y presentes.

**Qué deberías ver:** `[2/1] [U_]` en `mdstat` (dos discos esperados, uno
presente; `U` = arriba, `_` = falta), `State : clean, degraded` en `--detail`
y una fila `removed` donde estaba el disco que falta. `/datos` sigue montado.
:::

## Paso 2 · Presenta el disco nuevo y añádelo

**Pregúntate:** el disco de reemplazo tiene que ser igual o mayor que el que
falta. ¿Lo es?

:::pista Cómo hacerlo
El reemplazo es un fichero de imagen. Para el sistema sea un disco, hay que
asociarlo a un dispositivo *loop*:
```bash
ls -lh /srv/disks/tc212-d3.img
L=$(sudo losetup -f --show /srv/disks/tc212-d3.img); echo "$L"
sudo mdadm /dev/md212 --add "$L"
cat /proc/mdstat
```
- `losetup -f` usa el primer dispositivo loop libre (`/dev/loopN`) y
  `--show` imprime cuál; lo guardamos en `L`.
- `mdadm /dev/md212 --add <disco>` mete el disco en el array. Como falta uno,
  mdadm empieza a copiarle los datos.

**Qué deberías ver:** `recovery = 35.2% …` en `mdstat`.
:::

## Paso 3 · Espera a que termine

:::pista Cómo hacerlo
```bash
sudo mdadm --wait /dev/md212
cat /proc/mdstat
```
`--wait` no devuelve el control hasta que termina la reconstrucción.

**Qué deberías ver:** `[2/2] [UU]`. Durante todo el proceso `/datos` ha
seguido montado y el servicio escribiendo.
:::

## Paso 4 · Que sobreviva a un reinicio

:::pista Cómo hacerlo
```bash
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
bash /opt/lab/check.sh
```
`--detail --scan` imprime una línea `ARRAY /dev/md212 … UUID=…` por array.
En `mdadm.conf`, sirve para que al arrancar se monte el array identificándolo
por su UUID. En una máquina real, si el array se usa durante el arranque,
después hay que regenerar el initramfs (`sudo update-initramfs -u`).
:::

## Cómo actuar en una situación así

- Alertas: `MAILADDR` en `mdadm.conf` y el servicio de monitorización de mdadm.
  Un RAID degradado que nadie ve es un RAID0 a la espera.
- Antes de reconstruir, verifica que tienes copia de seguridad: la
  reconstrucción lee el disco superviviente entero, justo cuando más
  probable es que falle.
- En un fallo real: `mdadm /dev/mdX --fail /dev/sdY --remove /dev/sdY`, cambiar
  el disco físico, copiar la tabla de particiones y `--add`.

## Si te atascas

- **`device too small`:** el reemplazo es más pequeño que el array.
- **`--add` dice `busy`:** ese loop ya pertenece a otro array; usa otro.
- **El array aparece duplicado en `mdadm.conf`:** ejecutaste el `tee -a` dos
  veces. Deja una sola línea `ARRAY` por array.
