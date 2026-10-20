#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 12.
BL=/etc/dns-blocklist.conf
F=/home/analista/hallazgos.txt
DOM="cdn-sync.io"
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 12 — comprobación =="

if grep -q "$DOM" "$BL" 2>/dev/null; then
  ok "El dominio de exfiltración está en la blocklist."
else
  no "Falta añadir $DOM a $BL."
fi

if grep -q "$DOM" "$F" 2>/dev/null; then
  ok "Documentaste el dominio de exfiltración en el informe."
else
  no "Falta documentar $DOM en ~/hallazgos.txt."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Exfiltración por DNS bloqueada. ¡Lab 12 resuelto!"; exit 0; } || exit 1
