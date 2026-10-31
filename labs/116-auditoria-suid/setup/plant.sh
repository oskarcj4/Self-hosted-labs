#!/usr/bin/env bash
# Lab 116: la lista de referencia de SUID se tomó con el sistema limpio.
# Después aparecieron: una copia SUID de find escondida en /tmp, el bit SUID
# añadido a un binario legítimo de paquete y una copia de python con
# capability cap_setuid (no sale en find -perm -4000).
set -e
SCAN='find / -xdev -perm -4000 -type f 2>/dev/null | sort'
mkdir -p /home/analista/auditoria
bash -c "$SCAN" > /home/analista/auditoria/referencia-suid.txt
getcap -r / 2>/dev/null | sort > /home/analista/auditoria/referencia-caps.txt || true
cp /home/analista/auditoria/referencia-suid.txt /opt/lab/.ref-suid
cp /home/analista/auditoria/referencia-caps.txt /opt/lab/.ref-caps
chmod 0600 /opt/lab/.ref-*

mkdir -p /tmp/.cache
cp /usr/bin/find /tmp/.cache/.dbus-helper
chmod 4755 /tmp/.cache/.dbus-helper
touch -r /usr/bin/find /tmp/.cache/.dbus-helper
chmod u+s /usr/bin/vim.basic 2>/dev/null || chmod u+s /usr/bin/vim.tiny
cp "$(readlink -f /usr/bin/python3)" /usr/local/lib/.pyhelper
setcap cap_setuid+ep /usr/local/lib/.pyhelper

cat > /home/analista/auditoria/LEEME.txt <<'TXT'
Auditoría mensual de privilegios · srv-116
referencia-suid.txt  -> SUID del sistema recién instalado (find / -xdev -perm -4000 -type f)
referencia-caps.txt  -> capabilities de fichero en la misma fecha (getcap -r /)
Compara el estado actual con la referencia y documenta cada diferencia en
~/auditoria/informe.txt (ruta + qué es + qué hiciste).
TXT
chown -R analista:analista /home/analista/auditoria
echo "Lab 116 plantado."
