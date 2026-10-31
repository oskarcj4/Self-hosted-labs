#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
IF=$(cat /opt/lab/.lan-if)
for _ in 1 2 3 4 5; do ip neigh show 10.132.0.1; sleep 2; done
timeout 12 tcpdump -i $IF -nn -e -c 6 arp || true
arping -c 2 -I $IF 10.132.0.1 || true
arping -c 1 -I $IF 10.132.0.66 || true
cat > /home/analista/arp.txt <<'T'
ip_suplantada=10.132.0.1
mac_legitima=02:42:0a:84:00:01
mac_atacante=02:42:ba:dd:00:66
ip_atacante=10.132.0.66
T
chown analista:analista /home/analista/arp.txt
cat > /etc/systemd/system/arp-estatico.service <<U
[Unit]
Description=Entrada ARP estática de la puerta de enlace
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip neigh replace 10.132.0.1 lladdr 02:42:0a:84:00:01 dev $IF nud permanent
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now arp-estatico.service
systemctl enable --now arpwatch@$IF
sleep 2; pgrep -af arpwatch
