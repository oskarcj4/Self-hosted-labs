#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
J=http://127.0.0.1:16686/api

echo "== Lab 170 · OpenTelemetry — comprobación =="

for _ in 1 2 3 4 5; do curl -s -o /dev/null --max-time 5 http://127.0.0.1:8081/comprar; done
sleep 6

SVCS=$(curl -s "$J/services" | jq -r '.data[]?' 2>/dev/null)
if echo "$SVCS" | grep -qx front; then
  ok "Las trazas llegan a Jaeger a través del Collector."
else
  no "Jaeger no recibe trazas de front (¿receptor en 4318? ¿exporter otlp/jaeger en el pipeline?)."
fi

if echo "$SVCS" | grep -qx back && [ "$(systemctl show back -p Environment --value | grep -o 'OTEL_SERVICE_NAME=back')" ]; then
  ok "back se identifica como 'back'."
else
  no "No hay servicio 'back' en Jaeger (OTEL_SERVICE_NAME en back.service)."
fi

TR=$(curl -s "$J/traces?service=front&lookback=2m&limit=20")
JOINED=$(echo "$TR" | jq '[.data[]? | select([.processes[].serviceName] | (index("front") and index("back")))] | length' 2>/dev/null)
if [ "${JOINED:-0}" -ge 1 ]; then
  ok "Una petición a /comprar es UNA traza con spans de front y back ($JOINED trazas así en 2 min)."
else
  no "front y back no comparten traza: propaga el contexto (inject en front, extract en back)."
fi

L=$(grep -E '^\s*lento\s*=' /home/analista/traza.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')
if [ "$L" = consultar_bd ]; then
  ok "El tiempo se va en consultar_bd."
else
  no "~/traza.txt: lento=<span que se lleva el tiempo> (tienes '$L')."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Una petición, una traza, y el culpable a la vista."; exit 0; } || exit 1
