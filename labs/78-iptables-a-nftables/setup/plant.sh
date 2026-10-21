#!/usr/bin/env bash
# Lab 78 (fw-01): el cortafuegos corre con un script de iptables heredado de
# 2015. Hay que migrarlo a nftables nativo sin dejar el servidor fuera.
set -e
# El script heredado: políticas en ACCEPT, SSH abierto al mundo, reglas sueltas
# y comentarios de hace años. Se carga al arrancar con un servicio propio.
mkdir -p /etc/firewall
cat > /etc/firewall/rules-legacy.sh <<'EOF'
#!/bin/sh
# Cortafuegos de fw-01. Mantener con cuidado. -- equipo de redes, 2015
# (parcheado mil veces; nadie se acuerda del porqué de la mitad)
iptables -F
iptables -P INPUT ACCEPT          # TODO: cerrar esto algún día
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT      # SSH (abierto a todos!)
iptables -A INPUT -p tcp --dport 7681 -j ACCEPT    # consola web (ttyd)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT      # web antigua (ya no existe)
iptables -A INPUT -p tcp --dport 23 -j ACCEPT      # telnet (!!! quitar)
EOF
chmod 0755 /etc/firewall/rules-legacy.sh
cat > /etc/systemd/system/legacy-fw.service <<'EOF'
[Unit]
Description=Cortafuegos heredado (iptables, 2015)
After=network-pre.target
[Service]
Type=oneshot
ExecStart=/etc/firewall/rules-legacy.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable legacy-fw.service >/dev/null 2>&1
# nftables instalado pero inactivo, con el fichero de ejemplo de Debian.
systemctl disable nftables >/dev/null 2>&1 || true

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/CHG-7801.txt <<'EOF'
CHG-7801 · fw-01 · migrar el cortafuegos a nftables
- El cortafuegos usa un script de iptables de 2015
  (/etc/firewall/rules-legacy.sh, servicio legacy-fw.service). Auditoría lo
  rechaza: política por defecto ACCEPT, SSH abierto a todo Internet, y reglas
  de servicios que ya no existen (telnet/23, web/80).
- Migra a nftables NATIVO:
  * /etc/nftables.conf como única fuente, cargado por nftables.service.
  * Política de INPUT: drop. Permite lo de siempre: loopback,
    established,related, icmp/icmpv6 (ping).
  * SSH (22): SOLO desde las redes de administración, y con límite de ritmo
    para frenar fuerza bruta. Usa un SET llamado "admin_nets":
        10.76.78.0/24  y  192.168.10.0/24
  * La consola web (tcp/7681) sigue abierta (si la cierras, pierdes esta
    terminal).
  * Nada de telnet (23) ni web (80).
  * Desactiva el servicio heredado: nftables tiene que ser el único.
- Que sobreviva a un reinicio.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 78 plantado."
