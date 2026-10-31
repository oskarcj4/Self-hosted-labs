#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
A=/home/analista/auditoria
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /tmp/actual.txt
diff $A/referencia-suid.txt /tmp/actual.txt || true
getcap -r / 2>/dev/null
VIM=$(ls /usr/bin/vim.basic /usr/bin/vim.tiny 2>/dev/null | head -1)
dpkg -S /tmp/.cache/.dbus-helper || true     # ningún paquete: copia
dpkg -S "$VIM"                               # paquete legítimo con bit añadido
mkdir -p /root/cuarentena
sha256sum /tmp/.cache/.dbus-helper /usr/local/lib/.pyhelper > /root/cuarentena/sha256.txt
chmod u-s /tmp/.cache/.dbus-helper
mv /tmp/.cache/.dbus-helper /root/cuarentena/
chmod u-s "$VIM"
setcap -r /usr/local/lib/.pyhelper
mv /usr/local/lib/.pyhelper /root/cuarentena/
cat > $A/informe.txt <<TXT
/tmp/.cache/.dbus-helper  copia de find con SUID root, sin paquete (dpkg -S). Quitado SUID, a /root/cuarentena.
$VIM  binario del paquete vim con SUID añadido (no está en la referencia). chmod u-s.
/usr/local/lib/.pyhelper  copia de python3 con cap_setuid+ep (getcap). setcap -r y a cuarentena.
TXT
chown analista:analista $A/informe.txt
