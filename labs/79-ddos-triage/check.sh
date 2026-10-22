#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 79.
BL=/etc/ddos/blocklist.txt
TR=/home/analista/triage.txt
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 79 — comprobación =="

# Quitar comentarios y vacías para evaluar sólo las entradas reales.
entries() { grep -vE '^\s*(#|$)' "$BL" 2>/dev/null; }

if [ -f "$BL" ]; then ok "Existe la blocklist $BL."; else no "Falta $BL."; fi

if entries | grep -qE '203\.0\.113\.0/24'; then
  ok "La blocklist incluye el rango atacante 203.0.113.0/24."
else
  no "Falta el rango atacante 203.0.113.0/24 en la blocklist."
fi

if entries | grep -qE '198\.51\.100\.0/24'; then
  ok "La blocklist incluye el rango atacante 198.51.100.0/24."
else
  no "Falta el rango atacante 198.51.100.0/24 en la blocklist."
fi

if entries | grep -qE '10\.0\.0\.50'; then
  no "La blocklist bloquea el health check 10.0.0.50 (es legítimo: quítalo)."
else
  ok "No se bloquea el health check interno 10.0.0.50."
fi

if entries | grep -qE '66\.249\.66'; then
  no "La blocklist bloquea al crawler legítimo 66.249.66.x (quítalo)."
else
  ok "No se bloquea al crawler legítimo."
fi

if [ -f "$TR" ] && [ "$(wc -w < "$TR")" -ge 15 ]; then
  ok "Hay un análisis de triage en $TR."
else
  no "Escribe tu análisis (evidencia del ataque) en $TR."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Triage correcto: bloqueas al atacante, no a los tuyos. ¡Lab 79 resuelto!"; exit 0; } || exit 1
