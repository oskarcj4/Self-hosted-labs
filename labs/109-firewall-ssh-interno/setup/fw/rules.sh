#!/bin/sh
# Firewall del nodo de borde.  EDITA ESTE FICHERO (modo blue) y aplica con:
#   fw-reload
#
# Intención declarada: dejar solo la web pública (80) y bloquear desde fuera
# el SSH (22) y la consola admin interna (8080). Pero dos errores lo dejan
# saltar hasta el SSH.
IPT=iptables

$IPT -F

# Política por defecto. "ACCEPT para no cortar nada por error y vamos
# bloqueando lo sensible a mano."
$IPT -P INPUT ACCEPT
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# Tráfico local y respuestas de conexiones ya iniciadas por el propio nodo.
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Servicio público: permitido.
$IPT -A INPUT -p tcp --dport 80 -j ACCEPT

# Consola admin interna (8080): bloqueada desde fuera.
$IPT -A INPUT -p tcp --dport 8080 -j DROP

# SSH (22): "cerrado para que no entren desde fuera".
$IPT -A INPUT -p udp --dport 22 -j DROP
