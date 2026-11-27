# Resolución guiada · Lab 208

:::piensa Confianza cero
Todo lo que viene de un disco externo es hostil hasta demostrar lo contrario.
Montado con las opciones por defecto, el sistema respeta lo que traiga: un
programa con bit SUID se ejecuta como root, un fichero de dispositivo da
acceso directo a un disco del sistema. El primer paso es **mirar** sin
ejecutar nada; el segundo, montar de forma que el disco no pueda imponer nada.
:::

**El plan:** (1) ver cómo está montado, (2) inventariar lo peligroso,
(3) remontar con restricciones, (4) dejarlo en `fstab` y (5) comprobar.

## Paso 1 · ¿Cómo está montado?

:::pista Cómo hacerlo
```bash
findmnt /media/usb
ls -la /media/usb
```
`findmnt` muestra el dispositivo, el tipo de sistema de ficheros y las
opciones de montaje.

**Qué deberías ver:** `ext4` con `rw,relatime`: sin `nosuid`, `nodev` ni
`noexec`. Confianza total en el disco.
:::

## Paso 2 · Inventario

**Pregúntate:** ¿qué tres cosas de un disco ajeno pueden darte root o ejecutar
código?

:::pista Cómo hacerlo
```bash
sudo find /media/usb -xdev -type f \( -perm -4000 -o -perm -2000 \)
sudo find /media/usb -xdev \( -type b -o -type c \)
sudo find /media/usb -xdev -type f -perm -u+x
```

| Opción de `find` | Qué busca |
|---|---|
| `-xdev` | No salir de este sistema de ficheros. |
| `-perm -4000` / `-perm -2000` | Ficheros con bit SUID / SGID: se ejecutan con los permisos de su dueño o grupo, no con los tuyos. El `-` delante significa "al menos estos bits". |
| `-type b` / `-type c` | Ficheros de dispositivo de bloque (discos) o de carácter. Uno que apunte al disco del sistema permite leerlo y escribirlo saltándose los permisos. |
| `-perm -u+x` | Ficheros ejecutables. |

**Qué deberías ver:** `.mantenimiento` (una copia de `bash` con SUID root),
`sda1` (un dispositivo de bloque) y `autorun.sh`. Guárdalo todo, una ruta por
línea, **sin borrar nada** (es evidencia):
```bash
{ sudo find /media/usb -xdev -type f \( -perm -4000 -o -perm -2000 \)
  sudo find /media/usb -xdev \( -type b -o -type c \)
  sudo find /media/usb -xdev -type f -perm -u+x; } | sort -u > ~/hallazgos.txt
cat ~/hallazgos.txt
```
`{ …; }` agrupa los tres comandos para que su salida vaya junta a `sort -u`,
que la ordena y quita duplicados (un SUID también es ejecutable).
:::

## Paso 3 · Contén sin desmontar

:::pista Cómo hacerlo
```bash
sudo mount -o remount,nosuid,nodev,noexec /media/usb
findmnt /media/usb
```
`remount` cambia las opciones de un montaje activo sin desmontarlo.

| Opción | Qué hace |
|---|---|
| `nosuid` | Ignora los bits SUID/SGID del disco. |
| `nodev` | Ignora los ficheros de dispositivo. |
| `noexec` | Prohíbe ejecutar programas del disco. |

**Qué deberías ver:** `rw,nosuid,nodev,noexec,…`.
:::

## Paso 4 · Que sea así siempre

:::pista Cómo hacerlo
```bash
echo 'LABEL=PENDRIVE  /media/usb  ext4  nosuid,nodev,noexec,nofail  0  0' | sudo tee -a /etc/fstab
```
- `LABEL=PENDRIVE` identifica el disco por su etiqueta, no por el nombre
  `/dev/sdX`, que cambia según el orden en que se conecten.
- `nofail`: si el disco no está conectado, la máquina arranca igual.
:::

## Paso 5 · Comprueba

```bash
/media/usb/.mantenimiento -p -c id
bash /opt/lab/check.sh
```
`bash -p` mantiene los privilegios SUID en vez de descartarlos; antes del
arreglo, este comando decía `euid=0(root)`.

**Qué deberías ver:** `Permission denied`.

## Cómo actuar en una situación así

- Para analizar un disco como evidencia, móntalo además en **sólo lectura**
  (`ro`).
- Un USB normal es vfat o exFAT, que no soportan SUID ni dispositivos. Un USB
  con ext4 ya es una señal de alarma.
- `noexec` no es una barrera completa: `sh /media/usb/autorun.sh` sigue
  funcionando, porque quien se ejecuta es `/bin/sh`. Complementa con USBGuard,
  bloquear el módulo `usb-storage` y no automontar (lab 138).

## Si te atascas

- **El check dice que falta una ruta en `hallazgos.txt`:** tienen que ser rutas
  completas (`/media/usb/sda1`), una por línea.
- **`remount` dice `not mounted`:** comprueba la ruta con `findmnt`.
- **Sigue dando root:** lo ejecutas desde otra ruta. `findmnt -T <ruta>` dice
  en qué montaje está.
