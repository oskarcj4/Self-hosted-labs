#!/usr/bin/env bash
# Planta el escenario del Lab 08: web pública en :80 (correcto) y panel interno
# en :9000 expuesto a todos por una regla de iptables permisiva (el fallo).
set -e

# Servicios de juguete
mkdir -p /var/www/public /var/www/admin
echo "North Win - sitio publico" > /var/www/public/index.html
echo "PANEL DE ADMINISTRACION INTERNO" > /var/www/admin/index.html
( cd /var/www/public && nohup python3 -m http.server 80  >/dev/null 2>&1 & )
( cd /var/www/admin  && nohup python3 -m http.server 9000 >/dev/null 2>&1 & )

# Reglas de firewall: la de 9000/ACCEPT es el error que hay que corregir.
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 80   -j ACCEPT
iptables -A INPUT -p tcp --dport 9000 -j ACCEPT   # <-- expuesto a todos (mal)

echo "Lab 08 plantado. Entra como analista y lee /RETO.md"
