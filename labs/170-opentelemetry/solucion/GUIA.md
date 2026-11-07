# Resolución guiada · Lab 170

:::piensa Sigue el camino de un span
SDK → (OTLP/HTTP :4318) → receiver del Collector → pipeline → exporter →
(OTLP/gRPC :14317) → Jaeger. Comprueba cada salto en orden: ¿quién escucha
en 4318? ¿qué exporters tiene el pipeline?
:::

## Paso 1 · El Collector

:::pista Qué mirar
```bash
ss -ltnp | grep -E '4318|4319|14317'
grep -A3 pipelines -n /etc/otelcol/config.yaml
```
El receptor escucha en **4319** y el pipeline sólo exporta a `debug`.
:::

:::pista Cómo hacerlo
`endpoint: 127.0.0.1:4318` y `exporters: [otlp/jaeger, debug]`, luego
`otelcol-contrib validate --config ...` y `sudo systemctl restart otelcol`.
:::

## Paso 2 · unknown_service

:::pista Cómo hacerlo
`back.service` no define `OTEL_SERVICE_NAME`. Añade
`Environment=OTEL_SERVICE_NAME=back`, `daemon-reload` y reinicia back.
:::

## Paso 3 · Una sola traza

:::pista Qué falta
front hace la petición sin cabecera `traceparent`; back crea un span raíz
nuevo. Inyecta en front y extrae en back:
```python
headers = {}; propagate.inject(headers)
req = urllib.request.Request(url, headers=headers)
...
ctx = propagate.extract(self.headers)
with tracer.start_as_current_span("GET /stock", context=ctx, kind=SpanKind.SERVER):
```
:::

## Paso 4 · El span lento

:::pista Qué mirar
```bash
curl -s 'localhost:16686/api/traces?service=front&limit=1' \
 | jq -r '.data[0].spans[] | "\(.duration/1000|floor) ms  \(.operationName)"' | sort -n
```
Los spans padre incluyen a sus hijos; busca el hijo más largo.
:::

## Cómo actuar en una situación así

- Sin trazas: valida la config del Collector y mira sus logs antes de tocar el código.
- Usa la auto-instrumentación de librerías HTTP (requests, Flask...) cuando exista: propaga sola.
- Pon nombres de span de baja cardinalidad (`GET /stock`, no `GET /stock?id=123`).

## Si te atascas

- `journalctl -u otelcol` muestra errores de config al arrancar.
- Las trazas tardan ~1–5 s en aparecer (batch processor).
