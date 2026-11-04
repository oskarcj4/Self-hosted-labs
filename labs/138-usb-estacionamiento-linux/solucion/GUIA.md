# Resolución guiada · Lab 138

:::piensa Antes de tocar nada
Esto corre en tu equipo real y bajo tu propio riesgo. La pregunta no es
"¿cómo bloqueo los USB?", sino "¿cómo bloqueo los USB **sin dejarme fuera**?".
Inventario primero, política después, y siempre una vía para deshacer.
:::

## Paso 1 · ¿Qué hay conectado y de qué clase es?

**Pregúntate:** un teclado y un pendrive se distinguen por la clase de
interfaz USB. ¿Cuál es cada una?

:::pista Cómo comprobarlo
```bash
lsusb -t
```
`Class=Human Interface Device` (03) es teclado/ratón; `Class=Mass Storage`
(08) es almacenamiento. Un BadUSB enseña la 03 aunque parezca un pendrive.
:::

## Paso 2 · Lista de permitidos

**Pregúntate:** si generas la política con el pendrive sospechoso conectado,
¿qué pasa?

:::pista Cómo hacerlo
Quedaría en la lista de permitidos. Desconéctalo y genera:
```bash
sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
```
Pon arriba las reglas `reject with-interface all-of { 08:*:* 03:00:* }` y
`... 03:01:* }`, y `ImplicitPolicyTarget=block` en el daemon.
:::

## Paso 3 · Quita el almacenamiento USB del kernel

:::pista Cómo hacerlo
`blacklist` no basta: sólo frena la carga automática. Con
`install usb-storage /bin/false` también falla un `modprobe` manual.
Hazlo también con `uas` (los discos USB 3 rápidos usan ese módulo).
Comprueba con `modprobe -n -v usb-storage`.
:::

## Paso 4 · noexec para la excepción

**Pregúntate:** si mañana negocias una excepción para un pendrive cifrado de
la empresa, ¿qué impide que alguien ejecute un binario desde él?

:::pista Cómo hacerlo
`/etc/udisks2/mount_options.conf` con `defaults=noexec,nosuid,nodev`.
Pruébalo con un fichero montado como loop: `findmnt -no OPTIONS /dev/loopN`.
`noexec` no frena `bash script.sh` (lo ejecuta el intérprete): es una capa
más, no la única.
:::

## Paso 5 · Que quede rastro

:::pista Cómo comprobarlo
```bash
sudo journalctl -u usbguard -f        # conecta un USB no permitido
sudo usbguard list-devices --blocked
sudo ausearch -k usb-politica -i
```
:::

## Cómo actuar en una situación así

- Un USB encontrado **no se conecta** a un equipo de trabajo: se entrega a
  seguridad. Si hay que analizarlo, en un equipo aislado.
- Genera la política por tipo de equipo (portátiles, kioscos, servidores)
  y guárdala en gestión de configuración, no a mano.
- Vigila los cambios de política (auditd) igual que los dispositivos.

## Si te atascas

- Teclado bloqueado: entra por SSH o modo de recuperación, `systemctl disable usbguard`.
- `usbguard` dice "IPC connection refused": falta tu usuario en `IPCAllowedUsers` o usa `sudo`.
- `udisksctl loop-setup` pide contraseña: es polkit; es normal.
