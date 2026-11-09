#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 205.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 205 · Ampliar un EBS con partición ext4 — comprobación =="
SRC=$($SUDO findmnt -no SOURCE /datos 2>/dev/null)
FS=$($SUDO findmnt -no FSTYPE /datos 2>/dev/null)
[ -n "$SRC" ] && [ "$FS" = ext4 ] && ok "/datos sigue montado (ext4, $SRC)." || no "/datos no está montado como ext4."
PS=$($SUDO blockdev --getsize64 "$SRC" 2>/dev/null || echo 0)
[ "$(mb $PS)" -ge 790 ] && ok "La partición ocupa todo el disco ($(mb $PS) MiB)." || no "La partición sigue pequeña ($(mb $PS) MiB): falta growpart (y avisar al kernel con kpartx -u)."
SZ=$(df -BM --output=size /datos 2>/dev/null | tail -1 | tr -dc 0-9)
[ "${SZ:-0}" -ge 740 ] && ok "El sistema de ficheros mide ${SZ}M." || no "El sistema de ficheros sigue en ${SZ:-?}M: falta resize2fs."
AV=$(df -BM --output=avail /datos 2>/dev/null | tail -1 | tr -dc 0-9)
[ "${AV:-0}" -ge 500 ] && ok "Hay ${AV}M libres." || no "Sólo ${AV:-?}M libres (hacen falta 500M)."
( cd /datos && $SUDO sha256sum -c --quiet /opt/lab/manifest.sha256 >/dev/null 2>&1 ) && ok "Los 18 informes están intactos." || no "Faltan informes o están alterados."
$SUDO sh -c 'echo ok > /datos/.tc-write && rm -f /datos/.tc-write' 2>/dev/null && ok "/datos es escribible." || no "No se puede escribir en /datos."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Volumen ampliado en caliente: disco, partición y sistema de ficheros."; exit 0; } || exit 1
