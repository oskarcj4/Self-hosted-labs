#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 145.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
ROGUE=10.145.0.66
MAC=b8:27:eb:59:05:09

echo "== Lab 145 · La Raspberry Pi de Steel Mountain — comprobación =="

# Inventario hecho
if [ -f $H/inventario.txt ] && grep -q '10\.145\.0\.20' $H/inventario.txt && grep -q "$ROGUE" $H/inventario.txt; then
  ok "inventario.txt recoge el segmento (incluye corp-srv y el intruso)."
else
  no "~/inventario.txt debe tener la salida del barrido (al menos 10.145.0.20 y $ROGUE)."
fi

# Identificación del intruso
grep -qE "^rogue_ip=$ROGUE\s*$" $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: IP del intruso correcta ($ROGUE)." || no "hallazgos.txt: rogue_ip= no es $ROGUE."
grep -qiE "^rogue_mac=$MAC\s*$" $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: MAC del intruso correcta (OUI Raspberry Pi)." || no "hallazgos.txt: rogue_mac= no es $MAC."

# Regla de aislamiento presente
if $SUDO nft list ruleset 2>/dev/null | grep -q "$ROGUE"; then
  $SUDO nft list ruleset 2>/dev/null | grep "$ROGUE" | grep -q drop \
    && ok "nftables descarta el tráfico del intruso ($ROGUE)." || no "Hay una regla para $ROGUE pero no es 'drop'."
else
  no "No hay regla en nftables que mencione $ROGUE."
fi

# Prueba funcional: el intruso ya no es alcanzable desde la estación.
if $SUDO ping -c1 -W2 "$ROGUE" >/dev/null 2>&1; then
  no "Todavía se alcanza al intruso ($ROGUE): el aislamiento no es efectivo."
else
  ok "El intruso ya no responde desde la estación (aislado)."
fi

# Persistencia: la regla sobrevive a un reinicio (está en /etc/nftables.conf).
grep -q "$ROGUE" /etc/nftables.conf 2>/dev/null \
  && ok "El bloqueo es persistente (/etc/nftables.conf)." || no "El bloqueo no es persistente: añádelo a /etc/nftables.conf."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Intruso inventariado y aislado del segmento OT."; exit 0; } || exit 1
