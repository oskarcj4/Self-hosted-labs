# Disco externo montado sin restricciones

> Hardening · nosuid · nodev · noexec · fstab · evidencia

## Escenario

Un proveedor dejó un disco USB conectado a `usb-208` y alguien lo montó en
`/media/usb` con las opciones por defecto. Un disco externo es **no confiable**:
puede traer binarios SUID root, nodos de dispositivo que dan acceso directo a
discos del sistema, y scripts de "autorun".

| Opción | Qué hace |
|--------|----------|
| `nosuid` | Ignora los bits setuid/setgid del disco |
| `nodev` | Ignora los nodos de dispositivo (bloque/carácter) |
| `noexec` | Prohíbe ejecutar binarios del disco |

## Objetivos

1. Inventaría lo peligroso del disco en `~/hallazgos.txt` (una ruta por línea).
   **No borres nada**: es evidencia.
2. Remonta `/media/usb` con `nosuid,nodev,noexec` **sin desmontarlo**.
3. Deja la regla en `/etc/fstab` (por `LABEL=PENDRIVE`, con `nofail`).
4. Comprueba que el binario SUID ya no te da root.

## Comandos que te pueden servir

```bash
findmnt /media/usb
sudo find /media/usb -xdev -type f -perm -4000          # SUID
sudo find /media/usb -xdev \( -type b -o -type c \)     # nodos de dispositivo
sudo find /media/usb -xdev -type f -perm -u+x           # ejecutables
sudo mount -o remount,nosuid,nodev,noexec /media/usb
```

> `noexec` **no** es una barrera completa: `sh /media/usb/script.sh` o
> `/lib64/ld-linux-x86-64.so.2 /media/usb/bin` siguen ejecutando código. Se
> complementa con USBGuard, bloquear `usb-storage` y no automontar (lab 138).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
