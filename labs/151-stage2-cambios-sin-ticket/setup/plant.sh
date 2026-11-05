#!/usr/bin/env bash
# Lab 151 (Mr. Robot M10): stage 2, cambios sin ticket.
# /etc está versionado con etckeeper (git). Alguien metió cambios sin ticket:
# abrió root por SSH y dejó un cron oculto. El alumno los detecta con git,
# los revierte al estado aprobado y deja el árbol limpio.
set -e
export HOME=/root

# Identidad git para etckeeper.
git config --global user.email 'etckeeper@ecorp.local'
git config --global user.name  'etckeeper'
git config --global --add safe.directory /etc

# Línea base aprobada de /etc.
etckeeper init >/dev/null 2>&1 || true
etckeeper commit "baseline aprobado (cambios con ticket CHG)" >/dev/null 2>&1 || \
  git -C /etc commit -qam "baseline aprobado" 2>/dev/null || true

# --- STAGE 2: cambios NO autorizados (sin ticket) -----------------------------
# 1) Se abre root por SSH.
if grep -qiE '^\s*#?\s*PermitRootLogin' /etc/ssh/sshd_config; then
  sed -i -E 's/^\s*#?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi
# 2) Cron oculto que reestablece acceso.
cat > /etc/cron.d/stage2 <<'CR'
# (sin ticket) tarea de "mantenimiento"
*/5 * * * * root /usr/local/bin/.stage2 >/dev/null 2>&1
CR
chmod 0644 /etc/cron.d/stage2

# Los cambios quedan SIN commitear: así git los ve como pendientes.
touch -d "$(date +%Y-%m-%d) 02:38:00" /etc/ssh/sshd_config /etc/cron.d/stage2

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/CHG-151.txt <<'TXT'
CHG-151 · ecorp-151 · auditoría de configuración
/etc está versionado con etckeeper (git). La auditoría nocturna detectó cambios
en /etc que NO tienen ticket de cambio asociado. Hay que revisarlos y revertir
lo no aprobado.

1. Averigua qué cambió respecto a la línea base aprobada (git en /etc).
2. Revierte lo no autorizado: deja sshd_config como en la base y elimina lo
   que se haya añadido sin ticket. El árbol de /etc debe quedar limpio.
3. ~/cambios.txt: lista cada cambio no autorizado que encontraste.

Pistas:
  sudo git -C /etc status
  sudo git -C /etc diff
  sudo git -C /etc log --oneline
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 151 plantado."
