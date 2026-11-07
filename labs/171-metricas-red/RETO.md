# Métricas RED

> Observabilidad · Prometheus · instrumentación · Counter · Histogram · recording rules · Grafana

## Escenario

La tienda (`~/app/app.py`) tiene tres rutas: `/productos` (rápida), `/buscar`
(lenta) y `/pagar` (falla a veces). Sólo expone un contador `peticiones` sin
etiquetas: si `/pagar` empieza a fallar, la gráfica no cambia.

**RED** es el mínimo para cualquier servicio que atiende peticiones:

| Letra | Pregunta | Métrica |
|-------|----------|---------|
| **R**ate | ¿Cuántas peticiones por segundo? | Counter por ruta |
| **E**rrors | ¿Qué fracción falla? | el mismo Counter, por código |
| **D**uration | ¿Cuánto tardan (p99)? | Histogram por ruta |

Un **Histogram** guarda cuentas por cubos (`_bucket{le="0.5"}`); con
`histogram_quantile()` se calcula el p99 *agregando* réplicas. Una media
esconde la cola lenta; un Summary no se puede agregar.

## Objetivos

1. App instrumentada: `http_requests_total{route,code}` (Counter) y
   `http_request_duration_seconds{route}` (Histogram).
2. Prometheus rasca la app (target `tienda` en estado up).
3. Recording rules en `~/red/red-rules.yml`, agrupadas `by (route)`:
   `route:http_requests:rate1m`, `route:http_errors:ratio_rate1m`,
   `route:http_request_duration_seconds:p99_1m`.
4. Dashboard de Grafana **"RED tienda"** (`~/red/dashboards/red.json`, se
   provisiona solo) con paneles para las tres reglas.

## Pistas

```bash
curl -s localhost:8000/metrics | grep -v '^#' | head
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, health, lastError}'
sudo vi /etc/prometheus/prometheus.yml && curl -X POST localhost:9090/-/reload
promtool check rules ~/red/red-rules.yml
curl -s localhost:9090/api/v1/query --data-urlencode 'query=route:http_errors:ratio_rate1m' | jq
curl -s -u admin:tienda 'localhost:3000/api/search?query=RED'
```

```python
from prometheus_client import Counter, Histogram
REQS = Counter("http_requests", "Peticiones HTTP", ["route", "code"])   # se expone como http_requests_total
LAT  = Histogram("http_request_duration_seconds", "Latencia", ["route"])
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
