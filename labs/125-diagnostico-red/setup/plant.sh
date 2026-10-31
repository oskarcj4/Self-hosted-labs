#!/usr/bin/env bash
# Lab 125: la app va lenta. El fallo está en el router del proveedor (isp),
# no en la oficina. El alumno lo demuestra con ping/traceroute/mtr.
set -e
cat > /etc/systemd/system/rutas-oficina.service <<'U'
[Unit]
Description=Rutas de la oficina hacia el CPD
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=-/sbin/ip route add 10.125.3.0/24 via 10.125.1.2
ExecStart=-/sbin/ip route add 10.125.2.0/24 via 10.125.1.2
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now rutas-oficina.service
echo '10.125.3.10 srv-app' >> /etc/hosts
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/NET-125.txt <<'TXT'
NET-125 · oficina-125 · prioridad alta
"La aplicación (srv-app, 10.125.3.10) va lentísima y a ratos no carga."
El proveedor dice que su red está perfecta y que el problema es nuestro.
Demuestra con datos DÓNDE empieza el problema. Guarda el informe de mtr en
~/mtr.txt y tu conclusión en ~/diagnostico.txt:
  culpable=oficina|proveedor|servidor
  salto=<IP del primer salto donde empieza la pérdida>
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 125 plantado."
