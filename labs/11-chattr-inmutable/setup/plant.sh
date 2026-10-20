#!/usr/bin/env bash
# Planta el escenario del Lab 11: un payload inofensivo protegido con el atributo
# inmutable (chattr +i) sobre una imagen ext4 montada por loopback.
set -e
IMG=/opt/lab/data.img
MNT=/data
mkdir -p "$MNT"

if ! mountpoint -q "$MNT"; then
  dd if=/dev/zero of="$IMG" bs=1M count=16 status=none
  mkfs.ext4 -q -F "$IMG"
  mount -o loop "$IMG" "$MNT"
fi

cat > "$MNT/.payload" <<'EOF'
# payload de laboratorio (inofensivo). En un ataque real esto sería un binario
# malicioso protegido para que no lo puedas borrar.
EOF
chattr +i "$MNT/.payload"

echo "Lab 11 plantado. Entra como analista y lee /RETO.md"
