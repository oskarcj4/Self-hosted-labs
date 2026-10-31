#!/usr/bin/env bash
# Lab 131: en la LAN hay dos servidores DHCP. El falso contesta antes y
# reparte su propia puerta de enlace y DNS.
set -e
IF=$(ip -o -4 addr show | awk '/10\.131\.0\.10\//{print $2}')
echo "$IF" > /opt/lab/.lan-if
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/NET-131.txt <<TXT
NET-131 · portatil-131 · interfaz de la LAN: $IF
Varios portátiles reciben por DHCP una puerta de enlace "rara" y navegan
mal. El DHCP oficial de la oficina reparte 10.131.0.100-150.
1. Captura un intercambio DHCP completo en ~/dora.pcap (pide IP con dhclient en $IF).
2. Anota en ~/dhcp.txt:
     servidor_legitimo=<IP>   servidor_falso=<IP>   mac_falso=<MAC del falso>
3. Haz que este equipo ignore al servidor falso y obtenga IP del oficial.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 131 plantado."
