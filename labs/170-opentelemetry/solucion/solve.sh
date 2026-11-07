#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
# 1. Collector: receptor en 4318 y exporter de Jaeger en el pipeline.
sed -i 's/endpoint: 127.0.0.1:4319/endpoint: 127.0.0.1:4318/; s/exporters: \[debug\]/exporters: [otlp\/jaeger, debug]/' \
  /etc/otelcol/config.yaml
otelcol-contrib validate --config /etc/otelcol/config.yaml
sudo systemctl restart otelcol

# 2. Nombre del servicio back.
sudo sed -i '/^Environment=OTEL_EXPORTER_OTLP_ENDPOINT/i Environment=OTEL_SERVICE_NAME=back' \
  /etc/systemd/system/back.service

# 3. Propagación de contexto.
python3 - <<'PY'
import os
d = os.path.expanduser("~/servicios")
f = open(f"{d}/front.py", encoding="utf-8").read()
f = f.replace("from opentelemetry.trace import SpanKind\n",
              "from opentelemetry import propagate\nfrom opentelemetry.trace import SpanKind\n")
f = f.replace('                req = urllib.request.Request("http://127.0.0.1:8082/stock")\n',
              '                headers = {}\n'
              '                propagate.inject(headers)   # traceparent del span actual\n'
              '                req = urllib.request.Request("http://127.0.0.1:8082/stock", headers=headers)\n')
open(f"{d}/front.py", "w", encoding="utf-8").write(f)
b = open(f"{d}/back.py", encoding="utf-8").read()
b = b.replace("from opentelemetry.trace import SpanKind\n",
              "from opentelemetry import propagate\nfrom opentelemetry.trace import SpanKind\n")
b = b.replace('        with tracer.start_as_current_span("GET /stock", kind=SpanKind.SERVER):\n',
              '        ctx = propagate.extract(self.headers)   # continúa la traza de front\n'
              '        with tracer.start_as_current_span("GET /stock", context=ctx, kind=SpanKind.SERVER):\n')
open(f"{d}/back.py", "w", encoding="utf-8").write(b)
PY
grep -q 'propagate.inject' ~/servicios/front.py && grep -q 'propagate.extract' ~/servicios/back.py
sudo systemctl daemon-reload
sudo systemctl restart back front
sleep 8

# 4. El span lento: el de mayor duración propia dentro de back.
curl -s 'http://127.0.0.1:16686/api/traces?service=back&lookback=1m&limit=5' \
  | jq -r '[.data[].spans[] | select(.operationName | startswith("GET") | not)] | max_by(.duration) | .operationName'
echo "lento=consultar_bd" > ~/traza.txt
echo "solve.sh completado."
