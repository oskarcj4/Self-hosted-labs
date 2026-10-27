#!/usr/bin/env bash
# Solución BLUE: convertir el firewall en lista blanca y quitar las reglas
# que no bloquean nada. (La vía RED se deja al alumno.)
set -e
F=/srv/fw/rules.sh

cat > "$F" <<'RULES'
#!/bin/sh
# Firewall del nodo de borde — lista blanca.
# Política por defecto DROP y se abre solo lo necesario (80). SSH (22) y la
# consola admin (8080) quedan bloqueados por la propia política por defecto.
IPT=iptables

$IPT -F
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# Tráfico local y respuestas de conexiones ya iniciadas por el propio nodo.
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Único servicio público permitido.
$IPT -A INPUT -p tcp --dport 80 -j ACCEPT
RULES

chown analista:analista "$F"
sh "$F"
echo "Reglas corregidas y aplicadas."
