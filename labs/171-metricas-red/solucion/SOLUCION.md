# Solución — Métricas RED

## 1. Instrumentación (`~/app/app.py`)

```python
from prometheus_client import Counter, Histogram, start_http_server

REQS = Counter("http_requests", "Peticiones HTTP", ["route", "code"])
LAT = Histogram("http_request_duration_seconds", "Duración de las peticiones", ["route"],
                buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 2.5))

    def do_GET(self):
        ruta = self.path.split("?")[0]
        fn = RUTAS.get(ruta)
        etiqueta = ruta if fn else "desconocida"
        inicio = time.perf_counter()
        code, body = fn() if fn else (404, b"no existe")
        LAT.labels(etiqueta).observe(time.perf_counter() - inicio)
        REQS.labels(etiqueta, str(code)).inc()
        ...
```

`sudo systemctl restart tienda`

## 2. Scrape

`/etc/prometheus/prometheus.yml`: target `127.0.0.1:8080` → `127.0.0.1:8000`,
y `curl -X POST localhost:9090/-/reload`.

## 3. Recording rules (`~/red/red-rules.yml`)

```yaml
groups:
  - name: red-tienda
    rules:
      - record: route:http_requests:rate1m
        expr: sum by (route) (rate(http_requests_total{job="tienda"}[1m]))
      - record: route:http_errors:ratio_rate1m
        expr: |
          sum by (route) (rate(http_requests_total{job="tienda",code=~"5.."}[1m]))
          /
          sum by (route) (rate(http_requests_total{job="tienda"}[1m]))
      - record: route:http_request_duration_seconds:p99_1m
        expr: histogram_quantile(0.99, sum by (route, le) (rate(http_request_duration_seconds_bucket{job="tienda"}[1m])))
```

## 4. Dashboard

`~/red/dashboards/red.json` con título "RED tienda" y tres paneles que usan
las tres reglas (ver `solve.sh`).

## Resultado esperado

| Ruta | Rate | Errors | p99 |
|------|------|--------|-----|
| /productos | ~18/s | 0 | ~0.03 s |
| /buscar | ~6/s | 0 | ~0.6–0.75 s |
| /pagar | ~15/s | ~0.10 | ~0.1 s |

## Por qué

- Un contador total sin etiquetas no distingue qué ruta falla.
- El Histogram permite p99 agregado entre réplicas; la media escondería la cola.
- Escoge cubos alrededor de tus objetivos de latencia: si todos los valores caen
  en un cubo, el cuantil sale interpolado y poco preciso.

## Más allá del lab

- Método USE (Utilization, Saturation, Errors) para recursos: CPU, disco, colas.
- Exemplars: enlazar un punto del histograma con la traza que lo produjo (lab 170).
- Alertas sobre estas reglas con burn rate (lab 172).
