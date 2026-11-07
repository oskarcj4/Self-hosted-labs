#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/slo/slo-rules.yml
P=http://127.0.0.1:9090

echo "== Lab 172 · SLO y presupuesto de error — comprobación =="

if promtool check rules "$R" >/dev/null 2>&1; then
  ok "promtool check rules: sintaxis correcta."
else
  no "promtool check rules $R falla."
fi

T=$(mktemp -d)
cp /opt/lab/tests/slo.test.yml "$T/"
if python3 /opt/lab/normaliza-reglas.py "$R" "$T/rules.yml" 2>/dev/null \
   && (cd "$T" && promtool test rules slo.test.yml) > "$T/out.txt" 2>&1; then
  ok "Tests ocultos superados: quema rápida, quema lenta, consumo normal y pico corto."
else
  F=$(grep -E '^\s+name:' "$T/out.txt" 2>/dev/null | sed 's/^\s*name: //; s/,$//' | sort -u | paste -sd ';' -)
  no "Tests ocultos fallidos: ${F:-ver promtool}."
  grep -E 'alertname:|expr:' "$T/out.txt" 2>/dev/null | sed 's/^\s*/      /' | head -8
fi
rm -rf "$T"

B=/home/analista/slo/presupuesto.txt
PM=$(grep -E '^\s*presupuesto_minutos\s*=' "$B" 2>/dev/null | cut -d= -f2 | tr -d ' ')
RM=$(grep -E '^\s*restante_minutos\s*=' "$B" 2>/dev/null | cut -d= -f2 | tr -d ' ')
if [ "${PM%.*}" = 216 ] && [ "${RM%.*}" = 66 ]; then
  ok "Presupuesto: 216 min en 30 días; quedan 66."
else
  no "~/slo/presupuesto.txt: presupuesto_minutos='$PM' restante_minutos='$RM' (revisa el cálculo)."
fi

RULES=$(curl -s "$P/api/v1/rules")
if echo "$RULES" | grep -q CheckoutSLOBurnRateRapida && ! echo "$RULES" | grep -q '"CheckoutErrores"'; then
  V=$(curl -s "$P/api/v1/query" --data-urlencode 'query=slo:sli_error:ratio_rate5m' | jq -r '.data.result | length')
  if [ "${V:-0}" -ge 1 ]; then
    ok "Prometheus carga las reglas nuevas y ya calcula slo:sli_error:ratio_rate5m."
  else
    ok "Prometheus carga las reglas nuevas (la serie aparecerá en unos segundos)."
  fi
else
  no "Prometheus no tiene cargadas las reglas nuevas (curl -X POST $P/-/reload)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Alertas que despiertan sólo cuando el presupuesto está en peligro."; exit 0; } || exit 1
