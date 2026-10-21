#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root en dns-01.
set -e
cat > /etc/dnsmasq.d/20-log.conf <<'EOF'
log-queries
log-facility=/var/log/dnsmasq.log
EOF
tr -d '\r' < /srv/threat-intel/feed-2026-10-20.txt | sed 's/#.*//' \
  | awk 'NF >= 2 {print tolower($2)}' | grep -vxE 'localhost|0\.0\.0\.0' \
  | grep -vxFf <(grep -v '^#' /srv/threat-intel/allowlist.txt | grep .) | sort -u \
  | sed 's|.*|address=/&/0.0.0.0|' > /etc/dnsmasq.d/50-blocklist.conf
dnsmasq --test
systemctl restart dnsmasq
sleep 20
awk '/query\[/ && $NF != "127.0.0.1" {print $(NF-2), $NF}' /var/log/dnsmasq.log | sort -u \
  | while read -r d ip; do
      [ "$(dig +short @127.0.0.1 "$d" | tail -1)" = 0.0.0.0 ] && echo "$ip"
    done | sort -u > /home/analista/infectado.txt
cat /home/analista/infectado.txt
chown analista:analista /home/analista/infectado.txt
