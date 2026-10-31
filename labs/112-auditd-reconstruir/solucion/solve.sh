#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
ausearch -k claves -i | grep -E 'auid=|exe=' | head -20 || true
ausearch -k sudoers -i | grep -E 'auid=|exe=' | head -20 || true
cat > /home/analista/hallazgos.txt <<'TXT'
QUIÉN:  auid=becario, entró por SSH desde 203.0.113.45 (uid=root: actuó como root tras entrar con su cuenta)
QUÉ:    usermod -p ... -s /bin/bash backup   -> /etc/shadow (key claves)
        tee -a /etc/sudoers                   -> backup ALL=(ALL) NOPASSWD:ALL (key sudoers)
CUÁNDO: ver ausearch -k claves -i / ausearch -k sudoers -i
operador: chage -M 90 (caducidad de contraseñas), cambio legítimo / ruido.
TXT
chown analista:analista /home/analista/hallazgos.txt
sed -i '/^backup .*NOPASSWD/d' /etc/sudoers
visudo -c
usermod -s /usr/sbin/nologin -p '*' backup
cat > /etc/audit/rules.d/50-claves.rules <<'R'
-w /etc/shadow -p wa -k claves
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
R
augenrules --load || true   # en Docker auditctl -R da EPERM; el fichero se genera igual
augenrules --check
