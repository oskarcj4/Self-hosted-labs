#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 08.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 08 — comprobación =="

RULES="$(iptables -S INPUT 2>/dev/null)"

if echo "$RULES" | grep -qE '\-\-dport 9000 -j ACCEPT$'; then
  no "Sigue existiendo la regla permisiva que acepta tcp/9000 (quítala)."
else
  ok "La regla permisiva de tcp/9000 fue eliminada."
fi

if echo "$RULES" | grep -qE '\-\-dport 9000 -j (DROP|REJECT)'; then
  ok "El puerto interno tcp/9000 está bloqueado (DROP/REJECT)."
else
  no "Falta una regla que bloquee tcp/9000 (DROP o REJECT)."
fi

if echo "$RULES" | grep -qE '\-\-dport 80 -j ACCEPT'; then
  ok "El puerto público tcp/80 sigue accesible."
else
  no "Dejaste sin acceso el puerto 80 (la web pública debe seguir abierta)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Red segmentada. ¡Lab 08 resuelto!"; exit 0; } || exit 1
