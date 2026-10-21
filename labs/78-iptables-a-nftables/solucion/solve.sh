#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root en fw-01.
set -e
install -m 0755 /opt/lab/solucion-nftables.conf /etc/nftables.conf 2>/dev/null \
  || cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    set admin_nets {
        type ipv4_addr
        flags interval
        elements = { 10.76.78.0/24, 192.168.10.0/24 }
    }
    chain input {
        type filter hook input priority filter; policy drop;
        iif "lo" accept
        ct state established,related accept
        ct state invalid drop
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        ip saddr @admin_nets tcp dport 22 ct state new limit rate 10/minute burst 5 packets accept
        tcp dport 7681 accept
    }
    chain forward { type filter hook forward priority filter; policy drop; }
    chain output { type filter hook output priority filter; policy accept; }
}
EOF
# Fuera el cortafuegos heredado, y limpia lo que dejó cargado iptables.
systemctl disable --now legacy-fw.service
iptables -F 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true
# nftables como único cortafuegos.
nft -c -f /etc/nftables.conf
systemctl enable --now nftables
nft list ruleset | head -5
