# Solución — OpenTelemetry

## Fallos

| # | Dónde | Fallo | Arreglo |
|---|-------|-------|---------|
| 1 | Collector, receiver | escucha en 4319, el SDK envía a 4318 | `endpoint: 127.0.0.1:4318` |
| 2 | Collector, pipeline | `exporters: [debug]` | `exporters: [otlp/jaeger, debug]` |
| 3 | back.service | sin `OTEL_SERVICE_NAME` | `Environment=OTEL_SERVICE_NAME=back` |
| 4 | front.py / back.py | no se propaga `traceparent` | `propagate.inject` / `propagate.extract` |

## Código

```python
# front.py
from opentelemetry import propagate
headers = {}
propagate.inject(headers)
req = urllib.request.Request("http://127.0.0.1:8082/stock", headers=headers)

# back.py
ctx = propagate.extract(self.headers)
with tracer.start_as_current_span("GET /stock", context=ctx, kind=SpanKind.SERVER):
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart otelcol back front
echo "lento=consultar_bd" > ~/traza.txt
```

## Traza resultante

```
front  GET /comprar           ~420 ms
front  └─ pedir_stock         ~415 ms
back      └─ GET /stock       ~410 ms
back         ├─ consultar_cache   ~5 ms
back         ├─ consultar_bd    ~400 ms   <- aquí
back         └─ calcular_precio  ~10 ms
```

## Por qué

- El Collector separa la app del backend: cambias Jaeger por Tempo tocando
  sólo el exporter.
- La propagación es lo que convierte spans sueltos en una traza distribuida.
  Si un salto no propaga (una cola, un proxy), la traza se rompe ahí.

## Más allá del lab

- Muestreo en el Collector (`tail_sampling`): guardar el 100 % de las trazas con
  error o lentas, y el 5 % del resto.
- Exemplars: enlazar el p99 de las métricas (lab 171) con una traza concreta.
- Tempo + Grafana en vez de Jaeger (lab 216).
