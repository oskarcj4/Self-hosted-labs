#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 212.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 212 · RAID1 degradado: sustituir un disco fallido — comprobación =="
D=/dev/md212
DET=$($SUDO mdadm --detail $D 2>&1)
echo "$DET" | grep -qE 'State : .*clean' && ! echo "$DET" | grep -qE 'State : .*(degraded|recovering|resyncing)' && ok "El array está limpio (no degradado)." || no "El array sigue degradado o reconstruyendo: $(echo "$DET" | grep 'State :' | head -1 | sed 's/^ *//')."
AD=$(echo "$DET" | awk '/Active Devices/{print $4}'); WD=$(echo "$DET" | awk '/Working Devices/{print $4}')
[ "${AD:-0}" = 2 ] && [ "${WD:-0}" = 2 ] && ok "2 discos activos de 2." || no "Dispositivos activos: ${AD:-?} de 2."
UU=$(echo "$DET" | awk '/UUID :/{print $3}' | head -1)
[ -n "$UU" ] && grep -E '^ARRAY' /etc/mdadm/mdadm.conf 2>/dev/null | grep -qi "$UU" && ok "El array está en /etc/mdadm/mdadm.conf." || no "Falta la línea ARRAY de este array en /etc/mdadm/mdadm.conf (mdadm --detail --scan)."
$SUDO mountpoint -q /datos && [ "$($SUDO findmnt -no SOURCE /datos)" = "$D" ] && ok "/datos sigue montado desde $D." || no "/datos no está montado desde $D."
( cd /datos && $SUDO sha256sum -c --quiet /opt/lab/manifest.sha256 >/dev/null 2>&1 ) && ok "Datos intactos (incluida la nota escrita con el array degradado)." || no "Faltan datos o cambiaron."
$SUDO losetup -a | grep -q tc212-d3 && ok "El disco de reemplazo (tc212-d3) forma parte del array." || no "El disco de reemplazo no está conectado."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 RAID1 reconstruido, persistente en mdadm.conf y con los datos intactos."; exit 0; } || exit 1
