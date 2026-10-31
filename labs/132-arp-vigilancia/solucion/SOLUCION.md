# Solución — ARP: vigila la puerta de enlace

## Qué pasaba

El intruso `10.132.0.66` (MAC `02:42:ba:dd:00:66`) envía ARP gratuitos
diciendo que `10.132.0.1` es suya. La MAC legítima del gateway es
`02:42:0a:84:00:01`.

## Arreglo

```bash
IF=$(cat /opt/lab/.lan-if)
ip neigh show 10.132.0.1
sudo timeout 12 tcpdump -i $IF -nn -e -c 6 arp
cat > ~/arp.txt <<'T'
ip_suplantada=10.132.0.1
mac_legitima=02:42:0a:84:00:01
mac_atacante=02:42:ba:dd:00:66
ip_atacante=10.132.0.66
T
sudo tee /etc/systemd/system/arp-estatico.service <<U
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
sudo systemctl daemon-reload
sudo systemctl enable --now arp-estatico.service
sudo systemctl enable --now arpwatch@$IF
bash /opt/lab/check.sh
```

## Más allá del lab

- Localiza la MAC atacante en la tabla del switch y aísla el puerto.
- DAI + DHCP snooping evitan el ataque en toda la LAN, no sólo en un equipo.
