#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista

# 1) Revocar cuentas de baja (bloquear; también valdría userdel -r)
passwd -l tyrell   >/dev/null
passwd -l scripted >/dev/null

# 2) Quitar la llave no aprobada de todos los authorized_keys
while IFS= read -r f; do sed -i '/darkarmy@exfil/d' "$f"; done \
  < <(find /home /root -name authorized_keys 2>/dev/null)

# 3) Eliminar sudoers.d del ex-empleado
rm -f /etc/sudoers.d/tyrell

# 4) Documentar
cat > $H/revocados.txt <<'R'
cuenta tyrell: bloqueada (BAJA 2015)
cuenta scripted: bloqueada (BAJA 2016, contratista)
llave SSH darkarmy@exfil: eliminada de /home/deploy/.ssh y /home/tyrell/.ssh
sudoers.d/tyrell: eliminado
R
chown analista:analista $H/revocados.txt
echo "solve.sh completado."
