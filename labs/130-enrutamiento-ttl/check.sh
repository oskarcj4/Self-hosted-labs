#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 130.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
val(){ grep -E "^$1=" /home/analista/ttl.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }

echo "== Lab 130 · Enrutamiento y TTL — comprobación =="
[ "$(sysctl -n net.ipv4.ip_forward)" = 1 ] && ok "ip_forward=1: el equipo reenvía paquetes." || no "net.ipv4.ip_forward sigue a 0."
v=$(cat /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | grep -E '^\s*net\.ipv4\.ip_forward\s*=' | tail -1 | awk -F= '{gsub(/[ \t]/,"",$2); print substr($2,1,1)}')
[ "$v" = 1 ] && ok "ip_forward persistente en sysctl.d." || no "ip_forward no es 1 de forma persistente (/etc/sysctl.d/)."
ip route show 10.130.3.0/24 | grep -q 'via 10.130.2.253' && ok "Ruta a 10.130.3.0/24 vía 10.130.2.253." || no "Falta la ruta a la DMZ (10.130.3.0/24) por r2."
$SUDO grep -rqsE '10\.130\.3\.0/24.*10\.130\.2\.253' /etc/systemd/system /etc/network /etc/systemd/network && ok "La ruta está guardada para el arranque." \
  || no "La ruta no es persistente (p. ej. en rutas-router.service)."

st=$(head -1 /srv/estado/pc.txt 2>/dev/null)
age=$(( $(date +%s) - ${st#* } )) 2>/dev/null || age=999
if [ "${st%% *}" = OK ] && [ "$age" -lt 30 ]; then ok "pc-oficina ya llega a srv-dmz."; else no "pc-oficina sigue sin llegar a srv-dmz (/srv/estado/pc.txt: ${st%% *})."; fi

[ "$(val ttl_respuesta)" = 63 ] && ok "ttl_respuesta correcto (64 − 1 router)." || no "ttl.txt: ttl_respuesta no es el TTL que ves en las respuestas."
[ "$(val saltos_pc)" = 2 ] && ok "saltos_pc correcto (router-130 y r2-dmz)." || no "ttl.txt: saltos_pc no es correcto."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 La oficina vuelve a llegar a la DMZ."; exit 0; } || exit 1
