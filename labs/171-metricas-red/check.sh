#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=http://127.0.0.1:9090
q(){ curl -s "$P/api/v1/query" --data-urlencode "query=$1"; }
val(){ q "$1" | jq -r '.data.result[0].value[1] // empty'; }

echo "== Lab 171 · Métricas RED — comprobación =="

M=$(curl -s --max-time 5 http://127.0.0.1:8000/metrics)
if echo "$M" | grep -qE '^http_requests_total\{.*route="/pagar"' && echo "$M" | grep -E '^http_requests_total\{' | grep -q 'code="500"' \
   && echo "$M" | grep -qE '^http_request_duration_seconds_bucket\{.*route="/buscar"'; then
  ok "La app expone http_requests_total{route,code} y el histograma http_request_duration_seconds."
else
  no "La app no expone http_requests_total con route y code, o http_request_duration_seconds (Histogram) con route."
fi

UP=$(q 'up{job="tienda"}' | jq -r '.data.result[0].value[1] // "0"')
if [ "$UP" = 1 ]; then
  ok "Prometheus rasca la app (up{job=\"tienda\"} = 1)."
else
  no "El target de Prometheus 'tienda' está caído (up=$UP)."
fi

RULES=$(curl -s "$P/api/v1/rules" | jq -r '.data.groups[].rules[].name' 2>/dev/null)
NR=0
for r in route:http_requests:rate1m route:http_errors:ratio_rate1m route:http_request_duration_seconds:p99_1m; do
  echo "$RULES" | grep -qx "$r" && NR=$((NR+1))
done
if [ "$NR" = 3 ]; then
  ok "Las tres recording rules están cargadas en Prometheus."
else
  no "Recording rules cargadas: $NR de 3 (¿~/red/red-rules.yml y curl -X POST $P/-/reload?)."
fi

ER=""; P99=""; RT=""
for _ in $(seq 1 12); do
  ER=$(val 'route:http_errors:ratio_rate1m{route="/pagar"}')
  P99=$(val 'route:http_request_duration_seconds:p99_1m{route="/buscar"}')
  RT=$(val 'route:http_requests:rate1m{route="/productos"}')
  [ -n "$ER" ] && [ -n "$P99" ] && [ -n "$RT" ] && [ "$ER" != NaN ] && [ "$P99" != NaN ] && break
  sleep 5
done
if python3 - "$ER" "$P99" "$RT" <<'PY'
import sys
try:
    er, p99, rt = (float(x) for x in sys.argv[1:4])
except ValueError:
    sys.exit(1)
sys.exit(0 if 0.03 <= er <= 0.25 and 0.3 <= p99 <= 1.5 and rt > 1 else 1)
PY
then
  ok "Las reglas dan valores con sentido: errores /pagar=$(printf '%.3f' "$ER"), p99 /buscar=$(printf '%.2f' "$P99")s, rate /productos=$(printf '%.1f' "$RT")/s."
else
  no "Valores raros: errores /pagar='$ER' (esperado ~0.1), p99 /buscar='$P99' (~0.6 s), rate /productos='$RT'."
fi

G=http://admin:tienda@127.0.0.1:3000
UID_=$(curl -s "$G/api/search?query=RED%20tienda&type=dash-db" | jq -r '.[] | select(.title=="RED tienda") | .uid' | head -1)
if [ -n "$UID_" ]; then
  EXPRS=$(curl -s "$G/api/dashboards/uid/$UID_" | jq -r '[.dashboard.panels[]? , (.dashboard.panels[]?.panels[]?)] | .[].targets[]?.expr' 2>/dev/null)
  NP=0
  for r in route:http_requests:rate1m route:http_errors:ratio_rate1m route:http_request_duration_seconds:p99_1m; do
    echo "$EXPRS" | grep -qF "$r" && NP=$((NP+1))
  done
  if [ "$NP" = 3 ]; then
    ok "Dashboard 'RED tienda' en Grafana con paneles para Rate, Errors y Duration."
  else
    no "El dashboard 'RED tienda' sólo usa $NP de las 3 recording rules."
  fi
else
  no "Grafana no tiene el dashboard 'RED tienda' (~/red/dashboards/red.json)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Ahora se ve qué ruta falla y cuál va lenta."; exit 0; } || exit 1
