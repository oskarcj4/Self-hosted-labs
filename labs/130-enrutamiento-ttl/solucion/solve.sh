#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
ip -br addr; ip route
sysctl net.ipv4.ip_forward
sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.d/90-router.conf
sysctl --system >/dev/null
sed -i 's|^ExecStart=/bin/true|ExecStart=-/sbin/ip route add 10.130.3.0/24 via 10.130.2.253|' /etc/systemd/system/rutas-router.service
systemctl daemon-reload && systemctl restart rutas-router.service
ip route
T=$(ping -c 1 10.130.3.30 | grep -o 'ttl=[0-9]*' | cut -d= -f2)
traceroute -n 10.130.3.30
printf 'ttl_respuesta=%s\nsaltos_pc=2\n' "$T" > /home/analista/ttl.txt
chown analista:analista /home/analista/ttl.txt
sleep 12; cat /srv/estado/pc.txt
