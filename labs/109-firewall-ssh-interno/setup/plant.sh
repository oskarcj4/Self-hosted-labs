#!/usr/bin/env bash
# Planta el escenario (corre como root). Genera banderas, arranca los servicios
# (web pública, SSH de mantenimiento, consola admin interna) y aplica el
# firewall vulnerable.
set -e

gen() { echo "TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"; }
USER_FLAG=$(gen); ROOT_FLAG=$(gen)

# Bandera user: la lee 'soporte' una vez dentro por SSH.
printf '%s\n' "$USER_FLAG" > /home/soporte/user.flag
chown soporte:soporte /home/soporte/user.flag; chmod 640 /home/soporte/user.flag
# Bandera root: el fichero solo lo lee root, pero la consola admin interna
# (8080, corre como root) la entrega a quien la alcance por localhost.
printf '%s\n' "$ROOT_FLAG" > /root/root.flag; chmod 600 /root/root.flag
# Copia que lee el servidor de la plataforma para validar lo que envía el alumno.
printf 'USER=%s\nROOT=%s\n' "$USER_FLAG" "$ROOT_FLAG" > /opt/lab/.flags
chmod 600 /opt/lab/.flags

install -d /srv/svc
cp /opt/lab/setup/svc/banner.py /srv/svc/banner.py

# Web pública (siempre permitida por el firewall).
install -d /srv/www
cp /opt/lab/setup/www/index.html /srv/www/index.html

# Reglas de firewall: editables por 'analista' en modo blue.
install -d /srv/fw
cp /opt/lab/setup/fw/rules.sh /srv/fw/rules.sh
chown analista:analista /srv/fw/rules.sh; chmod 644 /srv/fw/rules.sh

# --- SSH de mantenimiento (22) ------------------------------------------------
# Credencial de fábrica sin rotar: soporte:soporte. Solo cuenta 'soporte'.
install -d -m 0755 /run/sshd
ssh-keygen -A >/dev/null 2>&1 || true
cat > /etc/ssh/sshd_config <<'SSHD'
Port 22
AddressFamily inet
PermitRootLogin no
PasswordAuthentication yes
UsePAM no
AllowUsers soporte
PrintMotd no
Subsystem sftp internal-sftp
SSHD

# --- Servicios ---------------------------------------------------------------
pkill -f banner.py 2>/dev/null || true
pkill -f "http.server" 2>/dev/null || true
pkill -x sshd 2>/dev/null || true

# Web pública (80) como root, solo estáticos.
( cd /srv/www && nohup python3 -m http.server 80 --bind 0.0.0.0 >/tmp/www.log 2>&1 & )
# Consola admin interna (8080): corre como root, atada a 0.0.0.0, sin auth.
nohup python3 /srv/svc/banner.py 8080 /root/root.flag \
      "consola admin interna (root)" 0.0.0.0 >/tmp/admin.log 2>&1 &
# SSH de mantenimiento (22).
/usr/sbin/sshd

# Comandos de ayuda (modo blue). fw-apply re-aplica como root; analista lo
# llama con sudo acotado. check-blue.sh corre como root y no necesita sudo.
printf '#!/bin/sh\nexec sh /srv/fw/rules.sh\n' > /usr/local/bin/fw-apply
printf '#!/bin/sh\nsudo /usr/local/bin/fw-apply && echo "firewall recargado"\n' \
  > /usr/local/bin/fw-reload
printf '#!/bin/sh\nsudo iptables -S\n' > /usr/local/bin/fw-show
chmod 0755 /usr/local/bin/fw-apply /usr/local/bin/fw-reload /usr/local/bin/fw-show
echo 'analista ALL=(root) NOPASSWD: /usr/local/bin/fw-apply, /usr/sbin/iptables' \
  > /etc/sudoers.d/analista
chmod 440 /etc/sudoers.d/analista

sleep 1
sh /srv/fw/rules.sh
echo "escenario listo (modo ${TCLAB_MODE:-blue})."
