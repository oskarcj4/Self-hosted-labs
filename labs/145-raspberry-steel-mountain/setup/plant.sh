#!/usr/bin/env bash
# Lab 145 (Mr. Robot M3): la Raspberry Pi de Steel Mountain.
# En el segmento hay un dispositivo que nadie dio de alta: una Raspberry Pi
# (OUI b8:27:eb) que habla con el controlador OT/HVAC. El alumno inventaria la
# red, identifica al intruso por su MAC y lo aísla con nftables.
set -e
export HOME=/root
H=/home/analista

# nftables arranca con una tabla vacía (política accept): el alumno añade el bloqueo.
cat > /etc/nftables.conf <<'NFT'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
	chain input   { type filter hook input   priority 0; policy accept; }
	chain forward { type filter hook forward priority 0; policy accept; }
	chain output  { type filter hook output  priority 0; policy accept; }
}
NFT
systemctl enable --now nftables

# Herramienta de inventario: barrido ARP del segmento.
cat > /usr/local/bin/inventario <<'SH'
#!/usr/bin/env bash
# Barre 10.145.0.0/24 y muestra IP + MAC de lo que responde.
echo "Barriendo 10.145.0.0/24 ..."
for i in $(seq 1 254); do ping -c1 -W1 "10.145.0.$i" >/dev/null 2>&1 & done
wait
echo "IP               MAC                vendedor(OUI)"
ip -4 neigh show | awk '/10\.145\.0\./ && $5 ~ /:/ {printf "%-16s %-18s %s\n", $1, $5, substr($5,1,8)}' | sort -t. -k4 -n
SH
chmod 0755 /usr/local/bin/inventario

# Inventario aprobado (CMDB): lo que SÍ debe existir en el segmento.
install -d -m 0755 /etc/red
cat > /etc/red/activos-aprobados.txt <<'TXT'
# Activos aprobados en el segmento 10.145.0.0/24 (CMDB)
10.145.0.10   estacion-145   estación del analista
10.145.0.20   corp-srv       servidor corporativo
10.145.0.50   hvac-ctrl      controlador HVAC (OT)
# Cualquier otra cosa en este segmento es NO aprobada.
TXT

mkdir -p $H/ticket
cat > $H/ticket/OT-145.txt <<'TXT'
OT-145 · Steel Mountain · "el aire acondicionado hace cosas raras"
Sospecha: hay un equipo conectado al segmento que nadie dio de alta y que
habla con el controlador HVAC. La CMDB de activos aprobados está en
/etc/red/activos-aprobados.txt

1. Inventaria el segmento (herramienta: inventario) y guarda la salida en
   ~/inventario.txt
2. Compara con la CMDB. El intruso delata su origen por el OUI de la MAC
   (b8:27:eb = Raspberry Pi Foundation). Apunta en ~/hallazgos.txt:
     rogue_ip=<IP>
     rogue_mac=<MAC completa>
3. Aísla el dispositivo con nftables: que no pueda entrar ni salir del
   segmento (ni alcanzar el HVAC). Deja la regla persistente.
TXT
chown -R analista:analista $H/ticket
echo "Lab 145 plantado."
