#!/usr/bin/env bash
# Planta el escenario del Lab 84: el DDoS acaba de terminar. El servicio vuelve,
# pero sin medidas no hay nada que impida que vuelva a caer. Hay evidencia en el
# log y una blocklist ya confirmada (del triage). Toca cerrar el incidente:
# aplicar mitigación duradera + escribir el postmortem.
set -e
echo "<h1>web-84 OK</h1>" > /var/www/html/index.html

LOG=/var/log/apache2/access.log
mkdir -p /var/log/apache2 /etc/ddos
: > "$LOG"
# Rastro del ataque recién terminado
for net in 203.0.113 198.51.100; do
  for host in $(seq 1 40); do
    for r in $(seq 1 10); do
      echo "$net.$host - - [10/Oct/2026:11:3$((r%6)):0$((r%6)) +0000] \"GET /buscar?q=%25%25%25 HTTP/1.1\" 503 540 \"-\" \"python-requests/2.31.0\"" >> "$LOG"
    done
  done
done
sort -R "$LOG" -o "$LOG" 2>/dev/null || true

# Blocklist ya confirmada en el triage (labs 79)
cat > /etc/ddos/blocklist.txt <<'EOF'
203.0.113.0/24
198.51.100.0/24
EOF
chmod 644 /etc/ddos/blocklist.txt

# Firewall limpio (sin medidas todavía)
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
apachectl start >/dev/null 2>&1 || service apache2 start >/dev/null 2>&1 || true

echo "Lab 84 plantado. Entra como analista y lee /RETO.md"
