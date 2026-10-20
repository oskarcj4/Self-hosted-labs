#!/usr/bin/env bash
# Planta el escenario del Lab 20: auth.log con fuerza bruta desde 198.51.100.23.
# fail2ban queda instalado pero SIN configurar: ésa es la tarea.
set -e
mkdir -p /var/log /etc/fail2ban
IP="198.51.100.23"
: > /var/log/auth.log
for i in $(seq 1 12); do
  echo "$(date '+%b %e %H:%M:%S') ssh-20 sshd[$((2000+i))]: Failed password for root from ${IP} port $((40000+i)) ssh2" >> /var/log/auth.log
done
echo "Lab 20 plantado. Entra como analista y lee /RETO.md"
