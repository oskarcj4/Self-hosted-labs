#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 132.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IF=$(cat /opt/lab/.lan-if 2>/dev/null)
val(){ grep -E "^$1=" /home/analista/arp.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r' | tr A-F a-f; }
GOOD=02:42:0a:84:00:01

echo "== Lab 132 · ARP spoofing — comprobación =="
[ "$(val ip_suplantada)" = 10.132.0.1 ] && ok "IP suplantada: la puerta de enlace." || no "arp.txt: ip_suplantada incorrecta."
[ "$(val mac_legitima)" = $GOOD ] && ok "MAC legítima del gateway." || no "arp.txt: mac_legitima incorrecta."
[ "$(val mac_atacante)" = 02:42:ba:dd:00:66 ] && ok "MAC del atacante." || no "arp.txt: mac_atacante incorrecta."
[ "$(val ip_atacante)" = 10.132.0.66 ] && ok "IP propia del atacante." || no "arp.txt: ip_atacante incorrecta."

n=$(ip neigh show 10.132.0.1 dev "$IF" 2>/dev/null)
echo "$n" | grep -qi "lladdr $GOOD" && echo "$n" | grep -q PERMANENT && ok "Entrada ARP estática (PERMANENT) con la MAC legítima." \
  || no "La entrada de 10.132.0.1 no es PERMANENT con la MAC legítima ($n)."
$SUDO grep -rqsiE "10\.132\.0\.1 .*$GOOD|$GOOD.*10\.132\.0\.1" /etc/systemd/system /etc/network /etc/ethers 2>/dev/null \
  && ok "La entrada estática está guardada para el arranque." || no "La entrada estática no es persistente (unidad systemd o similar)."
sleep 6
ip neigh show 10.132.0.1 dev "$IF" | grep -qi "$GOOD" && ok "Tras varios anuncios falsos, la caja sigue usando la MAC buena." || no "La caja ha vuelto a aprender la MAC falsa."

if pgrep -af arpwatch | grep -q -- "$IF"; then ok "arpwatch vigila $IF."; else no "arpwatch no está corriendo sobre $IF."; fi
systemctl is-enabled -q "arpwatch@$IF" 2>/dev/null && ok "arpwatch@$IF arranca con el sistema." || no "arpwatch@$IF no está habilitado."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Caja protegida y LAN vigilada."; exit 0; } || exit 1
