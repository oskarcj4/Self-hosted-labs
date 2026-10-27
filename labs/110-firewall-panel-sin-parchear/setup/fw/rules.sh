#!/bin/sh
# Firewall del appliance de borde — BIEN configurado (lista blanca).
# Política por defecto DROP; se abre solo la web pública (80) y el panel de
# gestión (10000). El SSH (22) y la consola admin (8080) internos quedan
# bloqueados desde fuera por la política por defecto.
#
# Este fichero NO es el fallo del lab: el firewall está correcto. El problema
# es que el software del panel (Webmin) está sin parchear. No hace falta tocar
# estas reglas.
IPT=iptables

$IPT -F
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# Tráfico local y respuestas de conexiones ya iniciadas por el propio nodo.
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Web pública.
$IPT -A INPUT -p tcp --dport 80 -j ACCEPT
# Panel de gestión (acceso legítimo de administración).
$IPT -A INPUT -p tcp --dport 10000 -j ACCEPT

# 22 (SSH) y 8080 (consola admin) internos: bloqueados por la política DROP.
