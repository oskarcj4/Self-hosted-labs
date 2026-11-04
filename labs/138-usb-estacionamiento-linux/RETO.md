# USB del estacionamiento (Linux): endurece tu equipo

> Guía en tu sistema · usbguard · usb-storage · noexec · auditd · journalctl

> ⚠️ **Esta guía no usa contenedor: todo se hace en TU sistema y bajo TU
> propio riesgo.** Vamos a endurecer la política de dispositivos externos
> de la máquina en la que trabajas. Una regla mal escrita puede bloquear tu
> teclado o ratón USB. Antes de empezar:
>
> - Hazlo en una **máquina virtual con snapshot** o en un equipo de pruebas.
>   Si lo haces en tu equipo de trabajo, ten a mano otra forma de entrar
>   (SSH desde otro equipo, o el modo de recuperación del arranque).
> - Lee la sección **Deshacer todo** antes de aplicar nada.
> - Ningún comando de esta guía envía datos fuera de tu equipo.

## Escenario

Alguien dejó un pendrive con la etiqueta "Nóminas 2026" en el
estacionamiento. Es un ataque clásico: la curiosidad hace el resto. El
pendrive puede traer malware ejecutable, o puede ser un BadUSB (como el
cable O.MG): un dispositivo que se presenta como **teclado** y escribe
comandos solo.

Tu política nueva tiene cuatro capas:

| Capa | Qué frena | Herramienta |
|------|-----------|-------------|
| Lista de dispositivos permitidos | Cualquier USB desconocido, también un falso teclado | `usbguard` |
| Sin almacenamiento USB | Pendrives y discos externos | módulo `usb-storage` / `uas` |
| Montaje sin ejecución | Binarios lanzados desde un medio que sí se permita | `noexec,nosuid,nodev` |
| Registro | Saber qué se conectó, cuándo y qué se cambió en la política | `auditd`, `journalctl` |

Comandos para Debian/Ubuntu. En Fedora/RHEL cambia `apt` por `dnf`.

## Paso 0 · Inventario y respaldo

```bash
mkdir -p ~/tclab-138 && cd ~/tclab-138
lsusb                        > lsusb-antes.txt   # qué hay conectado ahora
lsusb -t                    >> lsusb-antes.txt   # árbol: clase de cada interfaz (HID, Mass Storage...)
lsmod | grep -E 'usb_storage|uas' || echo "usb-storage no cargado"
sudo tar czf respaldo-etc.tgz /etc/modprobe.d /etc/usbguard /etc/udisks2 /etc/audit 2>/dev/null
```

Conecta **ahora** teclado, ratón, lector de huella, etc. que uses: la lista
de permitidos se genera a partir de lo que está conectado.

## Paso 1 · usbguard con lista de permitidos

```bash
sudo apt install usbguard
# Genera reglas "allow" para los dispositivos conectados AHORA.
sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
sudo cat /etc/usbguard/rules.conf
```

Revisa el fichero. Cada línea es `allow id VID:PID serial "..." name "..."
hash "..." with-interface ...`. El `hash` identifica el descriptor del
dispositivo: un clon con el mismo VID:PID no coincide.

Añade al **principio** de `rules.conf` una regla contra los BadUSB:
un dispositivo que dice ser almacenamiento **y** teclado a la vez se
rechaza siempre.

```text
reject with-interface all-of { 08:*:* 03:00:* }
reject with-interface all-of { 08:*:* 03:01:* }
```

Ajusta `/etc/usbguard/usbguard-daemon.conf`:

```ini
ImplicitPolicyTarget=block      # lo que no está en la lista, bloqueado
PresentDevicePolicy=apply-policy
InsertedDevicePolicy=apply-policy
IPCAllowedUsers=root            # añade tu usuario si quieres usar 'usbguard' sin sudo
```

```bash
sudo systemctl enable --now usbguard
sudo usbguard list-devices          # todo lo tuyo debe salir "allow"
```

> Si un dispositivo tuyo sale `block`: `sudo usbguard allow-device -p <id>`
> lo permite y lo guarda en las reglas (`-p` = permanente).

## Paso 2 · Sin almacenamiento USB

```bash
sudo tee /etc/modprobe.d/tclab-usb-storage.conf <<'EOF'
# TerminalCero lab 138: sin almacenamiento USB
blacklist usb-storage
blacklist uas
install usb-storage /bin/false
install uas /bin/false
EOF
sudo modprobe -r uas usb-storage 2>/dev/null || true   # descárgalos si estaban cargados
sudo update-initramfs -u      # Fedora/RHEL: sudo dracut -f
```

`blacklist` sólo evita la carga automática; `install ... /bin/false` hace
fallar también un `modprobe` manual.

## Paso 3 · Si algún día se permite un medio: sin ejecución

udisks2 es quien monta los pendrives en el escritorio. Fija sus opciones
de montaje por defecto:

```bash
sudo mkdir -p /etc/udisks2
sudo tee /etc/udisks2/mount_options.conf <<'EOF'
[defaults]
defaults=noexec,nosuid,nodev
EOF
sudo systemctl restart udisks2
```

Pruébalo sin pendrive, con un disco de mentira (fichero + loop):

```bash
truncate -s 20M /tmp/falso.img && mkfs.ext4 -q /tmp/falso.img
LOOP=$(udisksctl loop-setup -f /tmp/falso.img | grep -o '/dev/loop[0-9]*')
udisksctl mount -b "$LOOP"
findmnt -no OPTIONS "$LOOP"          # debe incluir noexec,nosuid,nodev
udisksctl unmount -b "$LOOP" && udisksctl loop-delete -b "$LOOP"
```

## Paso 4 · Registro: auditd y journalctl

```bash
sudo apt install auditd
sudo tee /etc/audit/rules.d/tclab-usb.rules <<'EOF'
-w /etc/usbguard/      -p wa -k usb-politica
-w /etc/modprobe.d/    -p wa -k usb-politica
-w /etc/udisks2/       -p wa -k usb-politica
-w /usr/bin/usbguard   -p x  -k usb-admin
EOF
sudo augenrules --load
sudo auditctl -l | grep usb
```

Ahora prueba: conecta **cualquier pendrive** (o un USB que no esté en la
lista) y mira qué quedó registrado:

```bash
sudo journalctl -u usbguard --since "10 min ago"
sudo journalctl -k --since "10 min ago" | grep -i usb
sudo usbguard list-devices --blocked
sudo ausearch -k usb-politica -i | tail -20
```

## Entregable

Guarda en `~/tclab-138/evidencia.txt`:

1. `sudo usbguard list-devices` (lo permitido y lo bloqueado).
2. Las líneas de `journalctl` del dispositivo bloqueado.
3. Las líneas de `ausearch -k usb-politica` de tus cambios.

## Verificación

El script sólo **lee** la configuración; no cambia nada:

```bash
sudo bash labs/138-usb-estacionamiento-linux/verificar.sh
```

## Deshacer todo

```bash
sudo systemctl disable --now usbguard
sudo rm -f /etc/modprobe.d/tclab-usb-storage.conf /etc/udisks2/mount_options.conf \
           /etc/audit/rules.d/tclab-usb.rules
sudo update-initramfs -u && sudo augenrules --load && sudo systemctl restart udisks2
```

Si usbguard bloqueó tu teclado: entra por SSH o arranca en modo de
recuperación y ejecuta `systemctl disable usbguard`.
