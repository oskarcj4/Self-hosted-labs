#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
grep COMMAND= /var/log/auth.log
ls -la /etc/sudoers.d/
mkdir -p /root/evidencia && cp -a /etc/sudoers.d/99-mantenimiento /root/evidencia/
rm /etc/sudoers.d/99-mantenimiento
cat > /etc/sudoers.d/10-deploy <<'S'
# Despliegues: reiniciar la app y editar su configuración (sin comodines).
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app, sudoedit /etc/app/app.conf
S
chmod 0440 /etc/sudoers.d/10-deploy
visudo -c
passwd -l soporte
sudo -l -U soporte || true
cat > /home/analista/informe-sudo.txt <<'TXT'
03:05 deploy entra por SSH con contraseña desde 198.51.100.23.
03:09 deploy: sudo /usr/bin/tee /etc/app/../sudoers.d/99-mantenimiento  -> el comodín /etc/app/* casa con '..'.
      Crea 99-mantenimiento: soporte ALL=(ALL) NOPASSWD: ALL
03:11 soporte entra desde la misma IP; 03:12 sudo /usr/bin/bash (shell root hasta 03:31).
Acciones: borrado 99-mantenimiento (copia en /root/evidencia), regla de deploy sin comodín (sudoedit),
cuenta soporte bloqueada, rotar contraseñas de deploy y soporte.
TXT
chown analista:analista /home/analista/informe-sudo.txt
