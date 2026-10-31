#!/usr/bin/env bash
# Lab 130: este equipo es el router de la oficina, pero no reenvía paquetes
# y no sabe llegar a la DMZ (falta la ruta vía r2).
set -e
sysctl -qw net.ipv4.ip_forward=0
echo 'net.ipv4.ip_forward = 0   # "por seguridad" (cambio 2024-03)' > /etc/sysctl.d/90-router.conf
cat > /etc/systemd/system/rutas-router.service <<'U'
[Unit]
Description=Rutas estáticas del router de la oficina
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
# Una línea ExecStart=-/sbin/ip route add <red> via <siguiente salto> por ruta.
ExecStart=/bin/true
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now rutas-router.service
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/NET-130.txt <<'TXT'
NET-130 · router-130
Los PCs de la oficina (10.130.1.0/24) no llegan al servidor de la DMZ
srv-dmz (10.130.3.30). La DMZ cuelga de r2-dmz (10.130.2.253).
Estado del PC de prueba (se actualiza cada 5 s): /srv/estado/pc.txt
Arréglalo de forma que sobreviva a un reinicio y responde en ~/ttl.txt:
  ttl_respuesta=<TTL de las respuestas de ping desde este router a 10.130.3.30>
  saltos_pc=<nº de routers entre pc-oficina y srv-dmz>
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 130 plantado."
