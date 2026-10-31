#!/usr/bin/env bash
# Lab 132: alguien en la LAN anuncia la IP de la puerta de enlace con su MAC.
set -e
IF=$(ip -o -4 addr show | awk '/10\.132\.0\.10\//{print $2}')
echo "$IF" > /opt/lab/.lan-if
# Tráfico normal de la caja hacia la puerta de enlace (TPV → pasarela de pago).
cat > /etc/systemd/system/tpv-latido.service <<'U'
[Unit]
Description=Latido del TPV hacia la puerta de enlace
[Service]
ExecStart=/bin/sh -c 'while :; do ping -c 1 -W 1 10.132.0.1 >/dev/null 2>&1; sleep 2; done'
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now tpv-latido.service
systemctl disable --now 'arpwatch*' >/dev/null 2>&1 || true
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/NET-132.txt <<TXT
NET-132 · caja-132 · interfaz de la LAN: $IF
Los pagos de esta caja fallan a ratos y el banco ha visto conexiones que no
salen de nuestro router. Puerta de enlace oficial: 10.132.0.1 (gw-tienda).
Rellena ~/arp.txt:
  ip_suplantada=   mac_legitima=   mac_atacante=   ip_atacante=
Protege esta caja (entrada ARP estática, que sobreviva a un reinicio) y deja
arpwatch vigilando la LAN.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 132 plantado."
