#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 131.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
IF=$(cat /opt/lab/.lan-if 2>/dev/null)
val(){ grep -E "^$1=" $H/dhcp.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r' | tr A-F a-f; }
ts(){ $SUDO tshark -r $H/dora.pcap -Y "$1" -T fields -e frame.number 2>/dev/null | wc -l; }

echo "== Lab 131 · DHCP y servidor falso — comprobación =="
if [ -s $H/dora.pcap ]; then
  d=$(ts 'dhcp.option.dhcp == 1'); o=$(ts 'dhcp.option.dhcp == 2'); r=$(ts 'dhcp.option.dhcp == 3'); a=$(ts 'dhcp.option.dhcp == 5')
  [ "$d" -ge 1 ] && [ "$o" -ge 1 ] && [ "$r" -ge 1 ] && [ "$a" -ge 1 ] && ok "dora.pcap: Discover, Offer, Request y ACK capturados." \
    || no "dora.pcap no tiene el DORA completo (D=$d O=$o R=$r A=$a)."
  srvs=$(ts 'dhcp.option.dhcp == 2 && ip.src == 10.131.0.66'); srvl=$(ts 'dhcp.option.dhcp == 2 && ip.src == 10.131.0.2')
  [ "$srvs" -ge 1 ] && [ "$srvl" -ge 1 ] && ok "Se ven ofertas de los dos servidores." || no "En dora.pcap no aparecen ofertas de ambos servidores."
else
  no "Falta ~/dora.pcap."; no "Sin captura no se ven las ofertas."
fi
[ "$(val servidor_legitimo)" = 10.131.0.2 ] && ok "Servidor legítimo identificado." || no "dhcp.txt: servidor_legitimo incorrecto."
[ "$(val servidor_falso)" = 10.131.0.66 ] && ok "Servidor falso identificado." || no "dhcp.txt: servidor_falso incorrecto."
[ "$(val mac_falso)" = 02:42:de:ad:be:ef ] && ok "MAC del servidor falso (para localizar su puerto en el switch)." || no "dhcp.txt: mac_falso incorrecta."

grep -hqsE '^\s*reject\s+[^;]*10\.131\.0\.66' /etc/dhcp/dhclient.conf && ok "dhclient.conf rechaza al servidor falso." || no "/etc/dhcp/dhclient.conf no rechaza 10.131.0.66."
last=$($SUDO sh -c 'cat /var/lib/dhcp/dhclient*.leases' 2>/dev/null | grep dhcp-server-identifier | tail -1 | grep -oE '[0-9.]+;' | tr -d ';')
[ "$last" = 10.131.0.2 ] && ok "La última concesión viene del DHCP oficial." || no "La última concesión no viene de 10.131.0.2 (viene de: ${last:-ninguna})."
if [ -n "$IF" ] && ip -4 addr show dev "$IF" | grep -qE 'inet 10\.131\.0\.(1[0-4][0-9]|150)/'; then
  ip -4 addr show dev "$IF" | grep -qE 'inet 10\.131\.0\.2[0-5][0-9]/' && no "$IF aún conserva una IP del servidor falso." || ok "$IF tiene una IP del rango oficial."
else
  no "$IF no tiene IP del rango oficial (10.131.0.100-150)."
fi
ip route | grep -q 'via 10.131.0.66' && no "Sigue habiendo una ruta por 10.131.0.66." || ok "Ninguna ruta pasa por el servidor falso."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 DHCP falso detectado y neutralizado en este equipo."; exit 0; } || exit 1
