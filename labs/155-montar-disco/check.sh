#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 155 · Montar un disco — comprobación =="

# 1) /mnt/datos es un punto de montaje
if $SUDO mountpoint -q /mnt/datos; then
  ok "/mnt/datos es un punto de montaje."
else
  no "/mnt/datos no está montado."
fi

# 2) El sistema de ficheros es ext4
FS=$($SUDO findmnt -no FSTYPE /mnt/datos 2>/dev/null)
if [ "$FS" = "ext4" ]; then
  ok "El sistema de ficheros montado es ext4."
else
  no "Se esperaba ext4 en /mnt/datos (hay '${FS:-nada}')."
fi

# 3) Es escribible
if $SUDO sh -c 'echo ok > /mnt/datos/.tc-write && rm -f /mnt/datos/.tc-write' 2>/dev/null; then
  ok "El disco montado es escribible."
else
  no "No se puede escribir en /mnt/datos."
fi

# 4) Está respaldado por la imagen del disco
SRC=$($SUDO findmnt -no SOURCE /mnt/datos 2>/dev/null)
if $SUDO losetup -a 2>/dev/null | grep -q 'data.img' || echo "$SRC" | grep -q loop; then
  ok "El montaje viene del disco entregado (/srv/disks/data.img vía loop)."
else
  no "El montaje no parece venir de /srv/disks/data.img."
fi

# 5) Persistencia en fstab
if $SUDO grep -qE '\s/mnt/datos\s' /etc/fstab 2>/dev/null; then
  ok "Hay una entrada en /etc/fstab para /mnt/datos (persistente)."
else
  no "Falta la entrada de /mnt/datos en /etc/fstab."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Disco formateado, montado y persistente."; exit 0; } || exit 1
