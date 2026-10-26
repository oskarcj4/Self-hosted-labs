#!/bin/sh
# Firewall del nodo de borde.  EDITA ESTE FICHERO (modo blue) y aplica con:
#   fw-reload
#
# Intención: permitir solo la web pública (80) y bloquear los servicios
# internos 9001 (usuario) y 9002 (admin). Pero dos reglas lo dejan saltar.
IPT=iptables

$IPT -F
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

# Tráfico local y respuestas de conexiones ya iniciadas por el propio nodo.
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Servicio público: permitido.
$IPT -A INPUT -p tcp --dport 80 -j ACCEPT

# "Para que vuelvan las respuestas DNS": confiar en el puerto de origen 53.
$IPT -A INPUT -p tcp --sport 53 -j ACCEPT

# Servicio de usuario (9001): se pretende bloquear.
$IPT -A INPUT -p tcp --dport 9001 -j DROP

# Consola admin (9002): ACCEPT de depuración que quedó puesto, antes del DROP.
$IPT -A INPUT -p tcp --dport 9002 -j ACCEPT
$IPT -A INPUT -p tcp --dport 9002 -j DROP
