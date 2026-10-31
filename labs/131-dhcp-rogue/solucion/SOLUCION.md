# Solución — DHCP: DORA y servidor falso

## Qué pasaba

Dos servidores DHCP en la LAN: el legítimo `10.131.0.2` (responde con 2 s de
retraso) y un impostor `10.131.0.66` (MAC `02:42:de:ad:be:ef`) que contesta
antes y se anuncia como puerta de enlace.

## Arreglo

```bash
IF=$(cat /opt/lab/.lan-if)
sudo tcpdump -i $IF -nn -e -w ~/dora.pcap 'port 67 or port 68' & P=$!
sleep 1; sudo timeout 20 dhclient -v -1 $IF; sleep 4; sudo kill $P
tshark -r ~/dora.pcap -T fields -e eth.src -e ip.src -e dhcp.option.dhcp -e dhcp.option.router
MAC=$(tshark -r ~/dora.pcap -Y 'dhcp.option.dhcp == 2 && ip.src == 10.131.0.66' -T fields -e eth.src | head -1)
printf 'servidor_legitimo=10.131.0.2\nservidor_falso=10.131.0.66\nmac_falso=%s\n' "$MAC" > ~/dhcp.txt
sudo chown analista:analista ~/dora.pcap

sudo dhclient -r $IF
echo 'reject 10.131.0.66;' | sudo tee -a /etc/dhcp/dhclient.conf
sudo timeout 30 dhclient -v -1 $IF
ip -4 addr show dev $IF; ip route
bash /opt/lab/check.sh
```

## Más allá del lab

- DHCP snooping + Dynamic ARP Inspection en los switches.
- 802.1X para que sólo equipos autenticados se conecten a la red.
