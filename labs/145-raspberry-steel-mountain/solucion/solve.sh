#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
sleep 5
/usr/local/bin/inventario > $H/inventario.txt 2>&1
MAC=$(ip -4 neigh show 10.145.0.66 | awk '{print $5}')
[ -n "$MAC" ] || MAC=b8:27:eb:59:05:09
cat > $H/hallazgos.txt <<H
rogue_ip=10.145.0.66
rogue_mac=$MAC
H
chown analista:analista $H/inventario.txt $H/hallazgos.txt

# Bloqueo en caliente
nft add rule inet filter input  ip saddr 10.145.0.66 drop
nft add rule inet filter output ip daddr 10.145.0.66 drop

# Persistencia
python3 - <<'PY'
p="/etc/nftables.conf"; s=open(p).read()
s=s.replace("chain input   { type filter hook input   priority 0; policy accept; }",
            "chain input   { type filter hook input   priority 0; policy accept; ip saddr 10.145.0.66 drop; }")
s=s.replace("chain output  { type filter hook output  priority 0; policy accept; }",
            "chain output  { type filter hook output  priority 0; policy accept; ip daddr 10.145.0.66 drop; }")
open(p,"w").write(s)
PY
systemctl restart nftables
echo "solve.sh completado. MAC=$MAC"
nft list ruleset | grep 10.145.0.66 || true
