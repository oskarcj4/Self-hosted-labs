#!/usr/bin/env bash
# Planta el escenario (corre como root). Genera banderas, arranca los tres
# servicios y aplica el firewall vulnerable.
set -e

gen() { echo "TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"; }
USER_FLAG=$(gen); ROOT_FLAG=$(gen)

# Banderas: la de user la lee 'svc' (servicio 9001); la de root solo root (9002).
install -d -o svc -g svc /srv/svc
printf '%s\n' "$USER_FLAG" > /srv/svc/user.flag
chown svc:svc /srv/svc/user.flag; chmod 640 /srv/svc/user.flag
printf '%s\n' "$ROOT_FLAG" > /root/root.flag; chmod 600 /root/root.flag
# Copia que lee el servidor de la plataforma para validar lo que envía el alumno.
printf 'USER=%s\nROOT=%s\n' "$USER_FLAG" "$ROOT_FLAG" > /opt/lab/.flags
chmod 600 /opt/lab/.flags

cp /opt/lab/setup/svc/banner.py /srv/svc/banner.py

# Web pública (siempre permitida por el firewall).
install -d /srv/www
cp /opt/lab/setup/www/index.html /srv/www/index.html

# Reglas de firewall: editables por 'analista' en modo blue.
install -d /srv/fw
cp /opt/lab/setup/fw/rules.sh /srv/fw/rules.sh
chown analista:analista /srv/fw/rules.sh; chmod 644 /srv/fw/rules.sh

# Servicios. Público (80) como root, pero solo sirve estáticos. user (9001)
# como svc. admin/root (9002) como root.
pkill -f banner.py 2>/dev/null || true
pkill -f "http.server" 2>/dev/null || true
( cd /srv/www && nohup python3 -m http.server 80 --bind 0.0.0.0 >/tmp/www.log 2>&1 & )
nohup runuser -u svc -- python3 /srv/svc/banner.py 9001 /srv/svc/user.flag \
      "servicio de usuario" >/tmp/user.log 2>&1 &
nohup python3 /srv/svc/banner.py 9002 /root/root.flag \
      "consola admin (root)" >/tmp/root.log 2>&1 &

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
