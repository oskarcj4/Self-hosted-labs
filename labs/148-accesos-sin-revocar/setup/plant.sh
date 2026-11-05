#!/usr/bin/env bash
# Lab 148 (Mr. Robot M7): accesos que nadie revocó.
# Gente que ya no está sigue teniendo puertas abiertas: cuentas huérfanas, una
# llave SSH no aprobada y un sudoers.d olvidado. El alumno revoca lo que sobra
# sin romper lo legítimo.
set -e
export HOME=/root
H=/home/analista

APROBADA='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApprovedOpsKeyAllsafe000000000000000000000001 ops@allsafe'
ROGUE='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDarkArmyRogueKeyExfil000000000000000000000002 darkarmy@exfil'

# --- cuentas huérfanas (ex-empleado y contratista que ya no están) ------------
for u in tyrell scripted deploy; do id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"; done
echo 'tyrell:tyrell2015' | chpasswd
echo 'scripted:contrato' | chpasswd

# --- sudoers.d olvidado del ex-empleado ---------------------------------------
echo 'tyrell ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tyrell
chmod 0440 /etc/sudoers.d/tyrell

# --- llaves SSH: una aprobada (deploy) + una NO aprobada dejada atrás ----------
install -d -m 0700 -o deploy -g deploy /home/deploy/.ssh
printf '%s\n%s\n' "$APROBADA" "$ROGUE" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 0600 /home/deploy/.ssh/authorized_keys
# La misma llave no aprobada quedó también en la cuenta del ex-empleado.
install -d -m 0700 -o tyrell -g tyrell /home/tyrell/.ssh
echo "$ROGUE" > /home/tyrell/.ssh/authorized_keys
chown tyrell:tyrell /home/tyrell/.ssh/authorized_keys
chmod 0600 /home/tyrell/.ssh/authorized_keys

# --- inventario IAM aprobado --------------------------------------------------
install -d -m 0755 /etc/iam
cat > /etc/iam/llaves-aprobadas.txt <<'TXT'
# Llaves SSH aprobadas (por comentario). Cualquier otra se revoca.
ops@allsafe
TXT
cat > /etc/iam/altas-bajas.txt <<'TXT'
# Altas y bajas de personal (RRHH)
tyrell    BAJA  2015-06-01  ex-empleado
scripted  BAJA  2016-02-20  contratista, contrato terminado
deploy    ALTA  -           cuenta de servicio de despliegue (activa)
analista  ALTA  -           tú
TXT

mkdir -p $H/ticket
cat > $H/ticket/IAM-148.txt <<'TXT'
IAM-148 · allsafe-148 · revisión de accesos
RRHH avisa: hay personal dado de baja que quizá conserva acceso. Cruza
/etc/iam/altas-bajas.txt (quién debe tener acceso) con lo que hay en el sistema.

1. Revoca las cuentas de quienes están de BAJA (bloquear o eliminar).
2. Quita toda llave SSH que NO esté en /etc/iam/llaves-aprobadas.txt
   (de cualquier authorized_keys). No toques la aprobada (ops@allsafe).
3. Elimina cualquier regla sudoers.d de personal que ya no está.
4. ~/revocados.txt: una línea por cosa revocada (cuentas, llave, sudoers).
TXT
chown -R analista:analista $H/ticket
echo "Lab 148 plantado."
