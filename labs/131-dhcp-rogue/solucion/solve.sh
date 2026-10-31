#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
IF=$(cat /opt/lab/.lan-if)
tcpdump -i $IF -nn -e -w $H/dora.pcap 'port 67 or port 68' & P=$!
sleep 1; timeout 20 dhclient -v -1 $IF || true; sleep 4; kill $P; wait $P 2>/dev/null || true
tshark -r $H/dora.pcap -T fields -e eth.src -e ip.src -e dhcp.option.dhcp -e dhcp.option.router
MAC=$(tshark -r $H/dora.pcap -Y 'dhcp.option.dhcp == 2 && ip.src == 10.131.0.66' -T fields -e eth.src | head -1)
printf 'servidor_legitimo=10.131.0.2\nservidor_falso=10.131.0.66\nmac_falso=%s\n' "$MAC" > $H/dhcp.txt
chown analista:analista $H/dora.pcap $H/dhcp.txt
dhclient -r $IF || true
echo 'reject 10.131.0.66;' >> /etc/dhcp/dhclient.conf
timeout 30 dhclient -v -1 $IF
ip -4 addr show dev $IF; ip route
