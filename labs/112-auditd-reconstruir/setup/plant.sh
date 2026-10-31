#!/usr/bin/env bash
# Lab 112: alguien tocó /etc/shadow y /etc/sudoers. El admin anterior dejó
# reglas de auditd puestas a mano (auditctl, no persistentes): el rastro está
# en audit.log, pero la vigilancia no sobrevivirá al próximo reinicio.
#
# El subsistema audit del kernel no está disponible dentro de Docker Desktop
# (EPERM incluso privilegiado), así que audit.log es la captura del servidor
# real, con el formato exacto del kernel; ausearch/aureport la leen igual.
set -e
systemctl disable --now auditd >/dev/null 2>&1 || true
id operador >/dev/null 2>&1 || useradd -m -u 1001 -s /bin/bash operador
id becario  >/dev/null 2>&1 || useradd -m -u 1002 -s /bin/bash becario
usermod -aG sudo operador; usermod -aG sudo becario

# Estado que dejó el intruso.
usermod -p '$6$xyz$Qe2b0Jm2dGQ1pK0Hn0mQ5pW8r1QnS0p6fE9i5h0v4b7Yc1Wd0zU3aG8sT2kL5nX9' -s /bin/bash backup
echo 'backup ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
chage -M 90 analista; chage -M 90 operador

mkdir -p /var/log/audit
python3 /opt/lab/setup/genaudit.py /var/log/audit/audit.log
chmod 0600 /var/log/audit/audit.log
# Sin reglas persistentes: sólo las que puso a mano el admin anterior.
rm -f /etc/audit/rules.d/*.rules /etc/audit/audit.rules
cat > /root/reglas-a-mano.txt <<'TXT'
# Reglas que cargó el admin anterior con auditctl (no persisten tras reiniciar):
auditctl -w /etc/shadow -p wa -k claves
auditctl -w /etc/sudoers -p wa -k sudoers
TXT

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-112.txt <<'TXT'
INC-112 · srv-rrhh-02
El monitor de integridad avisa: /etc/shadow y /etc/sudoers cambiaron hoy.
Nadie abrió cambio. Necesitamos: QUIÉN (cuenta con la que entró y desde dónde),
CUÁNDO y QUÉ comando lo hizo. Después, deshacer lo que hizo y que la vigilancia
sobreviva a un reinicio (el admin anterior las cargó a mano: /root/reglas-a-mano.txt).
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 112 plantado."
