#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 208.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 208 · Disco externo montado sin restricciones — comprobación =="
M=/media/usb
$SUDO mountpoint -q $M && ok "$M sigue montado (la evidencia sigue accesible)." || no "$M no está montado."
O=$($SUDO findmnt -no OPTIONS $M 2>/dev/null)
for f in nosuid nodev noexec; do echo ",$O," | grep -q ",$f," && ok "Montado con $f." || no "Falta la opción $f en el montaje actual."; done
FL=$(grep -E '^[^#]*[[:space:]]/media/usb[[:space:]]' /etc/fstab)
echo "$FL" | grep -q 'LABEL=PENDRIVE\|/dev/disk/by-label/PENDRIVE\|UUID=' && ok "fstab identifica el disco por etiqueta/UUID." || no "Falta la línea de /media/usb (LABEL=PENDRIVE) en /etc/fstab."
for f in nosuid nodev noexec nofail; do echo ",$(echo "$FL" | awk '{print $4}')," | grep -q ",$f," || { no "La línea de fstab no incluye $f."; MISS=1; }; done
[ -z "$MISS" ] && ok "fstab incluye nosuid,nodev,noexec,nofail."
$SUDO test -u $M/.mantenimiento && $SUDO test -b $M/sda1 && $SUDO test -f $M/autorun.sh && ok "La evidencia sigue intacta en el disco." || no "Faltan ficheros del disco: no borres la evidencia."
OUT=$(sudo -u analista $M/.mantenimiento -p -c 'id -u' 2>&1)
[ "$OUT" = "0" ] && no "El binario SUID sigue dando root a un usuario normal." || ok "El binario SUID ya no da root."
for p in .mantenimiento sda1 autorun.sh; do grep -qF "$M/$p" $H/hallazgos.txt 2>/dev/null && ok "hallazgos.txt incluye $p." || no "hallazgos.txt no incluye $M/$p."; done

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Dispositivo externo contenido: nosuid, nodev y noexec, también tras reiniciar."; exit 0; } || exit 1
