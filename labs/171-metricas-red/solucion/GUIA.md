# Resolución guiada · Lab 171

:::piensa ¿Qué pregunta responde cada métrica?
"¿Va bien la tienda?" se descompone en: ¿llegan peticiones? (Rate), ¿fallan?
(Errors), ¿tardan? (Duration). Siempre **por ruta**: un 10 % de fallos en
`/pagar` se diluye si lo mezclas con `/productos`.
:::

## Paso 1 · Instrumentar

:::pista Qué cambiar en app.py
```python
from prometheus_client import Counter, Histogram, start_http_server
REQS = Counter("http_requests", "Peticiones HTTP", ["route", "code"])
LAT = Histogram("http_request_duration_seconds", "Duración", ["route"],
                buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 2.5))
```
En `do_GET`: mide con `time.perf_counter()` alrededor de `fn()`, y luego
`LAT.labels(ruta).observe(dur)` y `REQS.labels(ruta, str(code)).inc()`.
:::

:::pista Cuidado con la cardinalidad
Si usas `self.path` tal cual como etiqueta, cada `?q=...` crea una serie
nueva. Usa la ruta sin query, y una etiqueta fija para rutas desconocidas.
:::

## Paso 2 · El scrape

:::pista Qué mirar
```bash
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, health, lastError}'
```
Rasca `:8080` (la app) en lugar de `:8000` (las métricas). Corrige y
`curl -X POST localhost:9090/-/reload`.
:::

## Paso 3 · Recording rules

:::pista Las tres expresiones
```promql
sum by (route) (rate(http_requests_total{job="tienda"}[1m]))
sum by (route) (rate(http_requests_total{job="tienda",code=~"5.."}[1m]))
  / sum by (route) (rate(http_requests_total{job="tienda"}[1m]))
histogram_quantile(0.99, sum by (route, le) (rate(http_request_duration_seconds_bucket{job="tienda"}[1m])))
```
En el cuantil, `le` debe sobrevivir al `sum`.
:::

## Paso 4 · Dashboard

:::pista Cómo hacerlo
JSON con `"title": "RED tienda"` y tres paneles `timeseries`, cada uno con
`"targets": [{"expr": "route:..."}]`. Grafana lee `~/red/dashboards` cada 10 s.
:::

## Cómo actuar en una situación así

- Instrumenta RED en el borde de cada servicio antes que nada más.
- Recording rules para lo que se consulta a menudo (paneles, alertas).
- Etiquetas con pocos valores posibles: ruta, código, método. Nunca usuario, id o URL completa.

## Si te atascas

- `histogram_quantile` da NaN: aún no hay datos en la ventana; espera 1 min.
- El dashboard no aparece: `sudo journalctl -u grafana | grep -i dashboard`.
