#!/usr/bin/env bash
# Lab 126: el puesto usa un resolver que miente sobre portal.empresa.lab.
set -e
for _ in $(seq 1 60); do dig +short +time=1 +tries=1 @10.126.0.53 portal.empresa.lab | grep -q . && break; sleep 2; done
# El resolver que "repartió" la red de invitados.
printf 'nameserver 10.126.0.99
options timeout:2
' > /etc/resolv.conf
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/DNS-126.txt <<'TXT'
DNS-126 · puesto-126
Un usuario dice que portal.empresa.lab "tiene otro aspecto" y le pide la
contraseña otra vez. Desde otros puestos va bien.
DNS interno oficial: 10.126.0.53 (valida DNSSEC; la zona empresa.lab está firmada).
Además: el equipo 10.126.0.25 aparece en los logs del firewall. ¿Cómo se llama?
Rellena ~/dns.txt:
  resolver_actual=<IP del resolver que usa este puesto>
  portal_falso=<IP que da ese resolver para portal.empresa.lab>
  portal_real=<IP según el DNS oficial>
  nombre_25=<nombre de 10.126.0.25>
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 126 plantado."
