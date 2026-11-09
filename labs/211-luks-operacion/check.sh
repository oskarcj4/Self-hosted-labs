#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 211.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 211 · Bóveda LUKS: rotar claves y no perder la cabecera — comprobación =="
IMG=/srv/disks/tc211-boveda.img
$SUDO cryptsetup isLuks $IMG && ok "La bóveda sigue siendo LUKS." || no "La bóveda ya no es LUKS."
printf %s 'Verano2023' | $SUDO cryptsetup open --test-passphrase --key-file - $IMG >/dev/null 2>&1 && no "La clave filtrada (Verano2023) sigue abriendo la bóveda." || ok "La clave filtrada ya no abre la bóveda."
K=/etc/luks/boveda.key
if $SUDO test -f $K; then
  [ "$($SUDO stat -c '%a %U' $K)" = "400 root" ] && ok "$K existe (root, 0400)." || no "$K debe ser root con modo 0400."
  [ "$($SUDO stat -c %s $K)" -ge 32 ] && ok "$K tiene tamaño suficiente." || no "$K es demasiado corto."
  $SUDO cryptsetup open --test-passphrase --key-file $K $IMG >/dev/null 2>&1 && ok "El keyfile del equipo abre la bóveda." || no "El keyfile del equipo no es un keyslot válido."
else no "Falta $K."; fi
if [ -f $H/boveda.header ]; then
  UI=$($SUDO cryptsetup luksUUID $IMG 2>/dev/null); UH=$($SUDO cryptsetup luksUUID $H/boveda.header 2>/dev/null)
  [ -n "$UI" ] && [ "$UI" = "$UH" ] && ok "~/boveda.header es una copia válida de la cabecera." || no "~/boveda.header no corresponde a esta bóveda (luksHeaderBackup)."
  [ "$(stat -c %a $H/boveda.header)" = 600 ] && ok "La copia de cabecera tiene modo 0600." || no "chmod 600 ~/boveda.header."
else no "Falta ~/boveda.header."; fi
grep -E '^boveda[[:space:]]+/srv/disks/tc211-boveda.img[[:space:]]+/etc/luks/boveda.key' /etc/crypttab >/dev/null 2>&1 && ok "/etc/crypttab apunta a la bóveda con el keyfile del equipo." || no "Falta la línea de /etc/crypttab (boveda IMG /etc/luks/boveda.key luks)."
grep -E '^[^#]*/dev/mapper/boveda[[:space:]]+/boveda[[:space:]]' /etc/fstab | grep -q nofail && ok "/etc/fstab monta /dev/mapper/boveda en /boveda (nofail)." || no "Falta la línea de fstab para /dev/mapper/boveda (con nofail)."
$SUDO mountpoint -q /boveda && [ "$($SUDO sha256sum /boveda/nominas.csv 2>/dev/null | cut -d' ' -f1)" = "$($SUDO cat /opt/lab/nominas.sha)" ] && ok "/boveda está abierta y nominas.csv intacto." || no "/boveda no está abierta y montada con nominas.csv intacto."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Bóveda operada: clave filtrada revocada, keyfile del equipo, cabecera respaldada y apertura automática."; exit 0; } || exit 1
