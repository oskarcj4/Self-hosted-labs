#!/usr/bin/env bash
# Lab 113: el servidor web expone base de datos, redis y un panel de pruebas.
# ufw está instalado pero inactivo, con reglas viejas que abren de más.
set -e
listener(){  # nombre puerto banner
  cat > /etc/systemd/system/$1.service <<UNIT
[Unit]
Description=$1 (servicio interno)
[Service]
ExecStart=/usr/bin/python3 -c "import socket;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('0.0.0.0',$2));s.listen(16)
while True:
  c,_=s.accept();c.sendall(b'$3\\\\r\\\\n');c.close()"
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
}
listener fake-mysql 3306 '5.7.44-log'
listener fake-redis 6379 '-NOAUTH Authentication required.'
listener panel-pruebas 8080 'HTTP/1.0 200 OK'
# Infraestructura del lab (no forma parte del reto): la terminal web entra por
# el 7681 y tiene que seguir viva aunque ufw niegue todo. Regla fuera de ufw,
# re-asegurada cada pocos segundos.
cat > /etc/systemd/system/tclab-terminal-fw.service <<'UNIT'
[Unit]
Description=TerminalCero: mantener accesible la terminal web (7681)
[Service]
ExecStart=/bin/bash -c 'while :; do iptables -C INPUT -p tcp --dport 7681 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport 7681 -j ACCEPT; sleep 3; done'
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now tclab-terminal-fw ssh nginx fake-mysql fake-redis panel-pruebas

# ufw inactivo con reglas heredadas de "cuando estábamos probando".
ufw --force reset >/dev/null
ufw allow 3306/tcp >/dev/null
ufw allow 8080/tcp >/dev/null
ufw allow 6379 >/dev/null
ufw disable >/dev/null || true

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/AUDIT-113.txt <<'TXT'
AUDIT-113 · web-113 (servidor web público)
El servidor sólo debe ofrecer al exterior: SSH (administración) y la web (80 y 443).
MySQL, Redis y el panel de pruebas son internos: no se pueden ver desde fuera.
El escáner externo deja su última pasada en /srv/escaneo/ultimo.txt (cada 15 s).
OJO: si activas el firewall antes de permitir SSH, en un servidor real te quedas fuera.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 113 plantado."
