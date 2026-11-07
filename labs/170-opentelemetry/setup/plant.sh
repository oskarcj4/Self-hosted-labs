#!/usr/bin/env bash
# Lab 170: dos servicios (front -> back) instrumentados con el SDK de
# OpenTelemetry mandan trazas al Collector, que debería reenviarlas a Jaeger.
# Fallos: el Collector escucha en otro puerto y sólo exporta a 'debug'; 'back'
# no tiene service.name; front no propaga el contexto (dos trazas sueltas).
set -e
H=/home/analista
S=$H/servicios
mkdir -p $S /etc/otelcol

# --- Jaeger (almacena y enseña las trazas) ------------------------------------
cat > /etc/systemd/system/jaeger.service <<'U'
[Unit]
Description=Jaeger all-in-one (memoria)
After=network.target
[Service]
Environment=SPAN_STORAGE_TYPE=memory
Environment=COLLECTOR_OTLP_GRPC_HOST_PORT=127.0.0.1:14317 COLLECTOR_OTLP_HTTP_HOST_PORT=127.0.0.1:14318
Environment=QUERY_HTTP_SERVER_HOST_PORT=127.0.0.1:16686
ExecStart=/usr/local/bin/jaeger-all-in-one
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- OpenTelemetry Collector ------------------------------------------------------
cat > /etc/otelcol/config.yaml <<'Y'
receivers:
  otlp:
    protocols:
      http:
        endpoint: 127.0.0.1:4319

processors:
  batch: {}

exporters:
  debug:
    verbosity: basic
  otlp/jaeger:
    endpoint: 127.0.0.1:14317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
Y
chown -R analista:analista /etc/otelcol
cat > /etc/systemd/system/otelcol.service <<'U'
[Unit]
Description=OpenTelemetry Collector
After=network.target jaeger.service
[Service]
ExecStart=/usr/local/bin/otelcol-contrib --config /etc/otelcol/config.yaml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
U

# --- Los servicios ---------------------------------------------------------------------
cat > $S/telemetria.py <<'PY'
"""Configuración común de OpenTelemetry para los servicios de la tienda.

El nombre del servicio sale de OTEL_SERVICE_NAME y el destino de
OTEL_EXPORTER_OTLP_ENDPOINT (variables estándar del SDK)."""
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def iniciar():
    provider = TracerProvider(resource=Resource.create())
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    return trace.get_tracer("tienda")
PY
cat > $S/front.py <<'PY'
"""front: recibe /comprar y pregunta el stock a back."""
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from opentelemetry.trace import SpanKind
import telemetria

tracer = telemetria.iniciar()


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        with tracer.start_as_current_span("GET /comprar", kind=SpanKind.SERVER):
            with tracer.start_as_current_span("pedir_stock", kind=SpanKind.CLIENT):
                req = urllib.request.Request("http://127.0.0.1:8082/stock")
                stock = urllib.request.urlopen(req, timeout=5).read()
            body = b'{"compra": "ok", "stock": ' + stock + b"}"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8081), H).serve_forever()
PY
cat > $S/back.py <<'PY'
"""back: responde /stock consultando caché y base de datos."""
import random, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from opentelemetry.trace import SpanKind
import telemetria

tracer = telemetria.iniciar()


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        with tracer.start_as_current_span("GET /stock", kind=SpanKind.SERVER):
            with tracer.start_as_current_span("consultar_cache"):
                time.sleep(random.uniform(0.002, 0.008))
            with tracer.start_as_current_span("consultar_bd") as span:
                span.set_attribute("db.system", "postgresql")
                time.sleep(random.uniform(0.35, 0.5))
            with tracer.start_as_current_span("calcular_precio"):
                time.sleep(random.uniform(0.005, 0.02))
        body = b"12"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8082), H).serve_forever()
PY
chown -R analista:analista $S

for svc in front back; do
  env_name=""; [ $svc = front ] && env_name="Environment=OTEL_SERVICE_NAME=front"
  cat > /etc/systemd/system/$svc.service <<U
[Unit]
Description=Tienda: $svc
After=otelcol.service
[Service]
User=analista
WorkingDirectory=$S
$env_name
Environment=OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
Environment=OTEL_BSP_SCHEDULE_DELAY=1000
ExecStart=/opt/otel/bin/python $S/$svc.py
Restart=always
[Install]
WantedBy=multi-user.target
U
done
cat > /etc/systemd/system/carga.service <<'U'
[Unit]
Description=Tráfico hacia front
After=front.service
[Service]
ExecStart=/bin/bash -c 'while true; do curl -s -o /dev/null --max-time 5 http://127.0.0.1:8081/comprar; sleep 1; done'
Restart=always
[Install]
WantedBy=multi-user.target
U

systemctl daemon-reload
systemctl enable --now jaeger otelcol back front carga
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:16686/api/services >/dev/null && break; sleep 1; done

cat > $H/TAREA.txt <<'TXT'
TAREA · Trazas distribuidas con OpenTelemetry

front (:8081) llama a back (:8082). Ambos usan el SDK de OpenTelemetry
(~/servicios) y mandan trazas por OTLP/HTTP a 127.0.0.1:4318, donde debería
estar el Collector (/etc/otelcol/config.yaml), que las reenvía a Jaeger.
En Jaeger (API: http://127.0.0.1:16686/api/...) no aparece nada.

1. Haz que las trazas lleguen a Jaeger: arregla el Collector (receptor y
   pipeline) y reinícialo:  sudo systemctl restart otelcol
2. El servicio back aparece como "unknown_service": dale nombre "back"
   (su unidad systemd: /etc/systemd/system/back.service).
3. front y back salen como trazas separadas. Propaga el contexto (W3C
   traceparent): una petición a /comprar = UNA traza con spans de los dos.
4. /comprar tarda ~0.4 s. ¿Qué span se lleva el tiempo? Escribe
   lento=<nombre del span> en ~/traza.txt.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 170 plantado."
