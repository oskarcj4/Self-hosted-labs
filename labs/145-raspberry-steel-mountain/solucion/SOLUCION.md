# Solución — La Raspberry Pi de Steel Mountain

## Qué pasaba

En el segmento hay 4 equipos, pero la CMDB sólo aprueba 3 (`.10`, `.20`, `.50`).
El cuarto, `10.145.0.66`, tiene MAC `b8:27:eb:59:05:09` (OUI de Raspberry Pi) y
está pinchando al controlador HVAC `10.145.0.50`. Es el intruso.

## Arreglo

```bash
# 1) Inventario
inventario | tee ~/inventario.txt
cat /etc/red/activos-aprobados.txt            # .10 .20 .50 aprobados

# 2) El que sobra -> su MAC delata el fabricante
ip neigh show | grep 10.145.0.66              # lladdr b8:27:eb:59:05:09
cat > ~/hallazgos.txt <<'H'
rogue_ip=10.145.0.66
rogue_mac=b8:27:eb:59:05:09
H

# 3) Aislar con nftables, en caliente y persistente
sudo nft add rule inet filter input  ip saddr 10.145.0.66 drop
sudo nft add rule inet filter output ip daddr 10.145.0.66 drop

# Persistencia: añade las dos reglas dentro de la tabla en /etc/nftables.conf
sudo python3 - <<'PY'
p="/etc/nftables.conf"; s=open(p).read()
ins="\t\tip saddr 10.145.0.66 drop\n"
s=s.replace("chain input   { type filter hook input   priority 0; policy accept; }",
            "chain input   { type filter hook input   priority 0; policy accept; ip saddr 10.145.0.66 drop; }")
s=s.replace("chain output  { type filter hook output  priority 0; policy accept; }",
            "chain output  { type filter hook output  priority 0; policy accept; ip daddr 10.145.0.66 drop; }")
open(p,"w").write(s)
PY
sudo systemctl restart nftables
sudo nft list ruleset | grep 10.145.0.66

# 4) Comprobar
ping -c1 -W2 10.145.0.66        # ya no responde
bash /opt/lab/check.sh
```

## Más allá del lab

- En OT real: VLAN dedicada, 802.1X por puerto, diodo de datos o cortafuegos
  industrial entre IT y OT. El bloqueo por IP es sólo contención inmediata.
- Un inventario que no se compara con la CMDB no sirve: la detección nace de la
  diferencia entre "lo que hay" y "lo que debería haber".
