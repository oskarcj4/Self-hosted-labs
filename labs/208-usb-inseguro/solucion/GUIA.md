# Resolución guiada · Lab 208

:::piensa Confianza cero
Todo lo que viene de un disco externo es hostil hasta demostrar lo contrario. El
primer paso es **mirar**, no ejecutar nada del disco.
:::

## Paso 1 · ¿Con qué opciones está montado?

:::pista Cómo comprobarlo
```bash
findmnt /media/usb
ls -la /media/usb
```
`rw,relatime` sin nosuid/nodev/noexec = confianza total.
:::

## Paso 2 · Inventario

**Pregúntate:** ¿qué tres cosas de un disco ajeno pueden escalar privilegios o ejecutar código?

:::pista Cómo hacerlo
```bash
sudo find /media/usb -xdev -type f -perm -4000
sudo find /media/usb -xdev \( -type b -o -type c \)
sudo find /media/usb -xdev -type f -perm -u+x
```
Anota las rutas en `~/hallazgos.txt`.
:::

## Paso 3 · Contener

:::pista Cómo hacerlo
```bash
sudo mount -o remount,nosuid,nodev,noexec /media/usb
findmnt /media/usb
```
:::

## Paso 4 · Persistir

:::pista Cómo hacerlo
```bash
echo 'LABEL=PENDRIVE  /media/usb  ext4  nosuid,nodev,noexec,nofail  0  0' | sudo tee -a /etc/fstab
```
:::

## Paso 5 · Prueba

:::pista Cómo hacerlo
```bash
/media/usb/.mantenimiento -p -c id    # Permission denied
```
:::

## Cómo actuar en una situación así

- Montaje sólo lectura (`ro`) para analizar el disco como evidencia.
- Un USB real suele ser vfat/exFAT (ignora SUID por diseño); ext4 en un USB es la señal de alarma.
- Controles en el equipo: `usbguard`, `modprobe -r usb-storage`, sin automontaje.

## Si te atascas

- `remount` dice "mount point not mounted": revisa la ruta con `findmnt`.
- Sigue dando root: el binario se ejecuta desde otro punto; `findmnt -T <ruta>`.
