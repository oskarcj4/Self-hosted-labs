#!/usr/bin/env bash
# Planta el escenario (corre como root). Genera banderas, arranca los servicios
# (web pública, panel Webmin vulnerable, SSH y consola admin internos) y aplica
# el firewall (que está bien configurado).
set -e

gen() { echo "TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"; }
USER_FLAG=$(gen); ROOT_FLAG=$(gen)

# Bandera user: foothold en el appliance (la lee quien logre ejecución).
install -d /var/lib/appliance
printf '%s\n' "$USER_FLAG" > /var/lib/appliance/user.flag
chmod 644 /var/lib/appliance/user.flag
# Bandera root: solo root. El RCE de Webmin corre como root -> alcanzable.
printf '%s\n' "$ROOT_FLAG" > /root/root.flag; chmod 600 /root/root.flag
# Copia que lee el servidor de la plataforma para validar lo que envía el alumno.
printf 'USER=%s\nROOT=%s\n' "$USER_FLAG" "$ROOT_FLAG" > /opt/lab/.flags
chmod 600 /opt/lab/.flags

install -d /srv/svc
cp /opt/lab/setup/svc/banner.py /srv/svc/banner.py

# Web pública (permitida por el firewall).
install -d /srv/www
cp /opt/lab/setup/www/index.html /srv/www/index.html

# Reglas de firewall (correctas): se aplican, no hace falta editarlas.
install -d /srv/fw
cp /opt/lab/setup/fw/rules.sh /srv/fw/rules.sh
chown analista:analista /srv/fw/rules.sh; chmod 644 /srv/fw/rules.sh

# --- SSH interno (22) --------------------------------------------------------
# Servicio de la zona protegida. El firewall lo tapa desde fuera.
install -d -m 0755 /run/sshd
ssh-keygen -A >/dev/null 2>&1 || true
cat > /etc/ssh/sshd_config <<'SSHD'
Port 22
AddressFamily inet
PermitRootLogin no
PasswordAuthentication no
PrintMotd no
Subsystem sftp internal-sftp
SSHD

# --- Panel de gestión Webmin (10000) · VULNERABLE (CVE-2019-15107) -----------
# La función de cambio de contraseña caducada debe estar activa (passwd_mode=2)
# para que el panel ofrezca password_change.cgi, igual que en un appliance real
# que permite a los usuarios renovar su clave.
sed -i 's/^passwd_mode=.*/passwd_mode=2/' /etc/webmin/miniserv.conf
grep -qi '^passwd_mode=' /etc/webmin/miniserv.conf || echo 'passwd_mode=2' >> /etc/webmin/miniserv.conf

# --- Arranque de servicios ---------------------------------------------------
pkill -f banner.py 2>/dev/null || true
pkill -f "http.server" 2>/dev/null || true
pkill -x sshd 2>/dev/null || true
/etc/webmin/stop >/dev/null 2>&1 || true

( cd /srv/www && nohup python3 -m http.server 80 --bind 0.0.0.0 >/tmp/www.log 2>&1 & )
nohup python3 /srv/svc/banner.py 8080 /root/root.flag \
      "consola admin interna (root)" 0.0.0.0 >/tmp/admin.log 2>&1 &
/usr/sbin/sshd
/etc/webmin/start >/tmp/webmin.log 2>&1

# Comandos de ayuda (modo blue).
printf '#!/bin/sh\nexec sh /srv/fw/rules.sh\n' > /usr/local/bin/fw-apply
printf '#!/bin/sh\nsudo /usr/local/bin/fw-apply && echo "firewall recargado"\n' \
  > /usr/local/bin/fw-reload
printf '#!/bin/sh\nsudo iptables -S\n' > /usr/local/bin/fw-show
# webmin-update: aplica el parche staged (1.930) y reinicia el panel.
cat > /usr/local/bin/webmin-do-update <<'UPD'
#!/bin/sh
set -e
DEB=/opt/lab/patches/webmin_1.930_all.deb
[ -f "$DEB" ] || { echo "no encuentro el paquete de actualización: $DEB"; exit 1; }
echo "actualizando Webmin -> 1.930 ..."
dpkg -i --force-depends "$DEB" >/tmp/webmin-update.log 2>&1 || true
sed -i 's/^passwd_mode=.*/passwd_mode=2/' /etc/webmin/miniserv.conf
/etc/webmin/stop >/dev/null 2>&1 || true
sleep 1
/etc/webmin/start >/tmp/webmin.log 2>&1
echo "Webmin ahora en versión $(cat /usr/share/webmin/version)"
UPD
printf '#!/bin/sh\nsudo /usr/local/bin/webmin-do-update\n' > /usr/local/bin/webmin-update
chmod 0755 /usr/local/bin/fw-apply /usr/local/bin/fw-reload /usr/local/bin/fw-show \
           /usr/local/bin/webmin-do-update /usr/local/bin/webmin-update
cat > /etc/sudoers.d/analista <<'SUDO'
analista ALL=(root) NOPASSWD: /usr/local/bin/fw-apply, /usr/sbin/iptables, /usr/local/bin/webmin-do-update
SUDO
chmod 440 /etc/sudoers.d/analista

sleep 1
sh /srv/fw/rules.sh
echo "escenario listo (modo ${TCLAB_MODE:-blue}). Webmin $(cat /usr/share/webmin/version) en :10000."
