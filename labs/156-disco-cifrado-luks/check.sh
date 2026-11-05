#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IMG=/srv/secure/vault.img

echo "== Lab 156 · Disco cifrado con LUKS — comprobación =="

# 1) La imagen es un contenedor LUKS
if $SUDO cryptsetup isLuks "$IMG" 2>/dev/null \
   || $SUDO losetup -a 2>/dev/null | grep -q vault.img && \
      $SUDO sh -c 'cryptsetup isLuks "$(losetup -j /srv/secure/vault.img -O NAME -n)"' 2>/dev/null; then
  ok "El disco está formateado con LUKS (cabecera presente)."
else
  # Comprobación directa por el loop asociado
  LB=$($SUDO losetup -j "$IMG" -O NAME -n 2>/dev/null | head -1)
  if [ -n "$LB" ] && $SUDO cryptsetup isLuks "$LB" 2>/dev/null; then
    ok "El disco está formateado con LUKS (cabecera presente)."
  else
    no "El disco no es LUKS: aplícale 'cryptsetup luksFormat'."
  fi
fi

# 2) Hay un volumen LUKS abierto (mapper activo)
MAP=$($SUDO dmsetup ls --target crypt 2>/dev/null | awk 'NF{print $1; exit}')
if [ -n "$MAP" ]; then
  ok "Hay un volumen LUKS abierto (/dev/mapper/$MAP)."
else
  no "No hay ningún volumen LUKS abierto (usa 'cryptsetup luksOpen')."
fi

# 3) Montado, ext4 y escribible
MP=""
for m in /mnt/vault /mnt/datos; do $SUDO mountpoint -q "$m" && MP="$m" && break; done
if [ -n "$MP" ] && [ "$($SUDO findmnt -no FSTYPE "$MP")" = "ext4" ]; then
  if $SUDO sh -c "echo ok > $MP/.tc && rm -f $MP/.tc" 2>/dev/null; then
    ok "El volumen descifrado está montado (ext4) y es escribible en $MP."
  else
    no "El volumen está montado pero no se puede escribir."
  fi
else
  no "Monta el dispositivo descifrado (/dev/mapper/...) en /mnt/vault como ext4."
fi

# 4) El montaje viene del mapper (dato realmente sobre la capa cifrada)
if [ -n "$MP" ]; then
  SRC=$($SUDO findmnt -no SOURCE "$MP" 2>/dev/null)
  if echo "$SRC" | grep -q '/dev/mapper/'; then
    ok "El montaje usa el dispositivo cifrado (/dev/mapper), no el loop en claro."
  else
    no "El montaje no viene de /dev/mapper (montaste el disco sin cifrar)."
  fi
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Volumen cifrado con LUKS, abierto y montado."; exit 0; } || exit 1
