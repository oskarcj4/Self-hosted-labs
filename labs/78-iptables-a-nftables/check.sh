#!/usr/bin/env bash
# Validador del Lab 78. Lee el ruleset de nftables REALMENTE cargado y lo
# vuelve a cargar desde /etc/nftables.conf para comprobar que persiste.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
end(){ echo "---------------------------------------"; echo "Resultado: $pass superados, $fail pendientes."; }

echo "== Lab 78 · iptables → nftables — comprobación =="

[ -f /etc/nftables.conf ] || { no "Falta /etc/nftables.conf."; end; exit 1; }
if ! nft -c -f /etc/nftables.conf 2>/tmp/nfterr; then
  no "/etc/nftables.conf no es válido: $(head -1 /tmp/nfterr)"; end; exit 1
fi
systemctl is-enabled --quiet nftables 2>/dev/null \
  && ok "nftables.service está habilitado (persiste al reinicio)." \
  || no "nftables.service no está habilitado (systemctl enable nftables)."
if systemctl is-enabled --quiet legacy-fw.service 2>/dev/null || systemctl is-active --quiet legacy-fw.service 2>/dev/null; then
  no "El servicio heredado legacy-fw sigue activo/habilitado: desactívalo (debe mandar sólo nftables)."
else
  ok "El cortafuegos heredado (legacy-fw) está desactivado."
fi

# Recarga desde el fichero: lo que se evalúa es el estado persistente.
nft flush ruleset
nft -f /etc/nftables.conf 2>/tmp/nfterr || { no "No carga: $(head -1 /tmp/nfterr)"; end; exit 1; }
R=$(nft -s list ruleset)
norm(){ echo "$R" | tr '\t' ' ' | sed 's/  */ /g'; }
N=$(norm)

echo "$N" | grep -qiE 'hook input .*policy drop' \
  && ok "La política de INPUT es drop." \
  || no "La cadena de INPUT no tiene 'policy drop'."

if echo "$R" | grep -qE 'set admin_nets' && \
   echo "$N" | grep -q '10.76.78.0/24' && echo "$N" | grep -q '192.168.10.0/24'; then
  ok "Existe el set admin_nets con las dos redes de administración."
else
  no "Falta el set 'admin_nets' con 10.76.78.0/24 y 192.168.10.0/24."
fi

ssh_lines=$(echo "$N" | grep -E 'dport (22|ssh)' )
if [ -z "$ssh_lines" ]; then
  no "No hay regla para SSH (22)."
elif echo "$ssh_lines" | grep -vq 'admin_nets'; then
  no "Hay una regla de SSH SIN restringir a admin_nets: $(echo "$ssh_lines" | grep -v admin_nets | head -1 | xargs)"
elif echo "$ssh_lines" | grep -q 'admin_nets' && echo "$ssh_lines" | grep -qE 'limit rate|limit name'; then
  ok "SSH sólo desde admin_nets y con límite de ritmo."
else
  no "SSH llega desde admin_nets pero sin límite de ritmo (limit rate ...)."
fi

echo "$N" | grep -qE 'dport (7681|.*7681).* accept' && ok "La consola web (7681) sigue abierta." \
  || no "El puerto 7681 no está permitido: perderías esta terminal."
echo "$N" | grep -qiE 'dport (23|telnet).* accept' && no "Sigue abierto telnet (23): quítalo." \
  || ok "Telnet (23) ya no está abierto."
echo "$N" | grep -qiE 'dport (80|http).* accept' && no "Sigue abierto el 80 (web que ya no existe): quítalo." \
  || ok "El puerto 80 ya no está abierto."

echo "$N" | grep -qiE 'iif(name)? "?lo"? accept' && ok "Loopback permitido." || no "Falta permitir loopback (iif lo accept)."
echo "$N" | grep -qiE 'ct state (established,related|related,established|established|related).* accept' \
  && ok "Permite conexiones establecidas/relacionadas." \
  || no "Falta 'ct state established,related accept'."
echo "$N" | grep -qi 'icmp' && ok "Permite ICMP (ping)." || no "Falta permitir ICMP."

# Liveness real: tras cargar tu ruleset, la consola web sigue respondiendo.
sleep 1
curl -fs --max-time 4 -o /dev/null http://127.0.0.1:7681/ \
  && ok "La consola web responde con tu cortafuegos cargado." \
  || no "La consola web (7681) no responde con tu ruleset cargado."

end
[ "$fail" -eq 0 ] && { echo "🎉 Cortafuegos en nftables: deny por defecto, SSH acotado, nada heredado de más."; exit 0; } || exit 1
