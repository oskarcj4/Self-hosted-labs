# Solución — Disco externo no confiable

## Qué pasaba

El disco se montó con `suid,dev,exec`. Traía `.mantenimiento` (copia de bash con SUID root),
`sda1` (nodo de dispositivo accesible a todos) y `autorun.sh`.

## Arreglo

```bash
sudo find /media/usb -xdev -type f -perm -4000        > ~/hallazgos.txt
sudo find /media/usb -xdev \( -type b -o -type c \)  >> ~/hallazgos.txt
sudo find /media/usb -xdev -type f -name autorun.sh  >> ~/hallazgos.txt
sudo mount -o remount,nosuid,nodev,noexec /media/usb
echo 'LABEL=PENDRIVE  /media/usb  ext4  nosuid,nodev,noexec,nofail  0  0' | sudo tee -a /etc/fstab
/media/usb/.mantenimiento -p -c id        # Permission denied
bash /opt/lab/check.sh
```

## Más allá del lab

- `ro` para forense; `udisks2`/`autofs` con opciones seguras para automontaje.
- USBGuard con lista blanca de dispositivos y `usb-storage` en la lista negra de módulos.
