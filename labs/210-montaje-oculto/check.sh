#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 210.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 210 · df dice lleno, du dice vacío — comprobación =="
$SUDO mountpoint -q /almacen && $SUDO mountpoint -q /almacen/datos && ok "/almacen y /almacen/datos siguen montados." || no "Falta algún montaje (/almacen o /almacen/datos)."
U=$(df -BM --output=used /almacen 2>/dev/null | tail -1 | tr -dc 0-9)
[ "${U:-999}" -le 20 ] && ok "/almacen usa ${U}M (< 20M)." || no "/almacen aún usa ${U:-?}M: queda espacio retenido (oculto o en ficheros borrados)."
V=$(mktemp -d); $SUDO mount --bind /almacen "$V"
NH=$($SUDO find "$V/datos" -type f 2>/dev/null | wc -l)
$SUDO umount "$V"; rmdir "$V"
[ "$NH" -eq 0 ] && ok "Ya no hay ficheros ocultos bajo el punto de montaje." || no "Aún hay $NH fichero(s) ocultos bajo /almacen/datos (mira con mount --bind)."
( cd /almacen/datos && $SUDO sha256sum -c --quiet /opt/lab/hidden.sha256 >/dev/null 2>&1 ) && ok "Las 5 subidas están en el disco de datos, intactas." || no "Las subidas no están (todas) en /almacen/datos."
[ "$($SUDO sha256sum /almacen/datos/clientes.db 2>/dev/null | cut -d' ' -f1)" = "$($SUDO cat /opt/lab/clientes.sha)" ] && ok "clientes.db intacto." || no "clientes.db falta o cambió."
DEL=$($SUDO lsof -nP +L1 2>/dev/null | awk '$7+0 > 1000000 && /almacen/' | wc -l)
[ "$DEL" -eq 0 ] && ok "Ningún proceso retiene ficheros borrados grandes." || no "Hay ficheros borrados grandes aún abiertos (lsof +L1)."
$SUDO systemctl is-active --quiet colector && ok "El servicio colector sigue activo." || no "El servicio colector no está activo."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Espacio recuperado: datos viejos movidos al disco correcto y archivo borrado liberado."; exit 0; } || exit 1
