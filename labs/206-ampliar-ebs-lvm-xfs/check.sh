#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 206.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 206 · Más espacio con LVM y XFS (EBS ampliado + EBS nuevo) — comprobación =="
$SUDO mountpoint -q /datos && [ "$($SUDO findmnt -no FSTYPE /datos)" = xfs ] && ok "/datos sigue montado (XFS)." || no "/datos no está montado como XFS."
NPV=$($SUDO vgs --noheadings -o pv_count vg206 2>/dev/null | tr -d ' ')
[ "${NPV:-0}" -ge 2 ] && ok "El VG vg206 tiene $NPV volúmenes físicos (disco nuevo añadido)." || no "El VG vg206 sigue con ${NPV:-?} PV: falta pvcreate + vgextend con el disco nuevo."
PVS=$($SUDO pvs --noheadings --units m --nosuffix -o pv_size 2>/dev/null | sort -n | tail -1 | cut -d. -f1 | tr -d ' ')
[ "${PVS:-0}" -ge 590 ] && ok "El PV ampliado mide ${PVS}M (pvresize hecho)." || no "El PV del disco ampliado sigue en ${PVS:-?}M: falta pvresize."
LV=$($SUDO lvs --noheadings --units m --nosuffix -o lv_size vg206/datos 2>/dev/null | cut -d. -f1 | tr -d ' ')
[ "${LV:-0}" -ge 850 ] && ok "El LV datos mide ${LV}M." || no "El LV datos sólo mide ${LV:-?}M (esperaba ≥ 850M)."
SZ=$(df -BM --output=size /datos 2>/dev/null | tail -1 | tr -dc 0-9)
[ "${SZ:-0}" -ge 820 ] && ok "El XFS mide ${SZ}M." || no "El XFS sigue en ${SZ:-?}M: falta xfs_growfs (o lvextend -r)."
( cd /datos && $SUDO sha256sum -c --quiet /opt/lab/manifest.sha256 >/dev/null 2>&1 ) && ok "Los 15 dumps están intactos (no recreaste el sistema de ficheros)." || no "Faltan dumps o están alterados."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 LVM ampliado con el disco crecido y el disco nuevo, XFS en caliente."; exit 0; } || exit 1
