# OpenTelemetry: trazas distribuidas

> Observabilidad · OpenTelemetry · OTLP · Collector · Jaeger · propagación de contexto

## Escenario

`front` (:8081) recibe `/comprar` y pregunta el stock a `back` (:8082). Los
dos usan el SDK de OpenTelemetry (`~/servicios`) y envían trazas por
**OTLP/HTTP** a `127.0.0.1:4318`. Ahí debería escuchar el **Collector**
(`/etc/otelcol/config.yaml`), que las reenvía a **Jaeger**.

En Jaeger no aparece nada.

Conceptos:

- **Traza** = el viaje de una petición. **Span** = un tramo con nombre,
  inicio y duración. Los spans forman un árbol.
- **Collector** = receivers → processors → exporters, unidos en *pipelines*.
  Un exporter definido pero fuera del pipeline no hace nada.
- **Propagación de contexto**: el cliente añade la cabecera `traceparent`
  (W3C) y el servidor la lee. Sin eso, cada servicio empieza su propia traza.
- El nombre del servicio es un atributo del *resource* (`service.name`;
  variable `OTEL_SERVICE_NAME`). Sin él: `unknown_service`.

## Objetivos

1. Las trazas llegan a Jaeger (Collector arreglado).
2. `back` aparece como `back`.
3. Una petición a `/comprar` = **una** traza con spans de `front` y `back`.
4. `~/traza.txt` con `lento=<nombre del span que se lleva el tiempo>`.

## Pistas

```bash
sudo journalctl -u otelcol -n 30
otelcol-contrib validate --config /etc/otelcol/config.yaml
curl -s localhost:16686/api/services | jq
curl -s 'localhost:16686/api/traces?service=front&limit=1' \
  | jq '.data[0].spans[] | {operationName, duration, svc: .processID}'
sudo systemctl edit back      # o edita /etc/systemd/system/back.service
sudo systemctl daemon-reload && sudo systemctl restart front back
```

```python
from opentelemetry import propagate
headers = {}; propagate.inject(headers)          # cliente
ctx = propagate.extract(self.headers)            # servidor
tracer.start_as_current_span("...", context=ctx, kind=SpanKind.SERVER)
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
