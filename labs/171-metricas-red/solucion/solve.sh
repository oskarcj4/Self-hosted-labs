#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
python3 - <<'PY'
import os
p = os.path.expanduser("~/app/app.py")
s = open(p, encoding="utf-8").read()
s = s.replace(
    'from prometheus_client import Counter, start_http_server\n\n'
    'PETICIONES = Counter("peticiones", "Peticiones recibidas")\n',
    'from prometheus_client import Counter, Histogram, start_http_server\n\n'
    'REQS = Counter("http_requests", "Peticiones HTTP", ["route", "code"])\n'
    'LAT = Histogram("http_request_duration_seconds", "Duración de las peticiones", ["route"],\n'
    '                buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 1, 2.5))\n')
s = s.replace(
    '        PETICIONES.inc()\n'
    '        fn = RUTAS.get(self.path.split("?")[0])\n'
    '        code, body = fn() if fn else (404, b"no existe")\n',
    '        ruta = self.path.split("?")[0]\n'
    '        fn = RUTAS.get(ruta)\n'
    '        etiqueta = ruta if fn else "desconocida"   # no dejar que la URL invente etiquetas\n'
    '        inicio = time.perf_counter()\n'
    '        code, body = fn() if fn else (404, b"no existe")\n'
    '        LAT.labels(etiqueta).observe(time.perf_counter() - inicio)\n'
    '        REQS.labels(etiqueta, str(code)).inc()\n')
open(p, "w", encoding="utf-8").write(s)
PY
grep -q 'REQS.labels' ~/app/app.py
sudo systemctl restart tienda

sudo sed -i 's/127.0.0.1:8080/127.0.0.1:8000/' /etc/prometheus/prometheus.yml

cat > ~/red/red-rules.yml <<'Y'
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
Y
promtool check rules ~/red/red-rules.yml
curl -sf -X POST http://127.0.0.1:9090/-/reload

cat > ~/red/dashboards/red.json <<'J'
{
  "title": "RED tienda",
  "uid": "red-tienda",
  "schemaVersion": 39,
  "time": {"from": "now-15m", "to": "now"},
  "refresh": "10s",
  "panels": [
    {"id": 1, "type": "timeseries", "title": "Rate (peticiones/s por ruta)",
     "gridPos": {"x": 0, "y": 0, "w": 8, "h": 8},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "reqps"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "route:http_requests:rate1m", "legendFormat": "{{route}}"}]},
    {"id": 2, "type": "timeseries", "title": "Errors (fracción 5xx por ruta)",
     "gridPos": {"x": 8, "y": 0, "w": 8, "h": 8},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "percentunit"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "route:http_errors:ratio_rate1m", "legendFormat": "{{route}}"}]},
    {"id": 3, "type": "timeseries", "title": "Duration (p99 por ruta)",
     "gridPos": {"x": 16, "y": 0, "w": 8, "h": 8},
     "datasource": {"type": "prometheus", "uid": "prometheus"},
     "fieldConfig": {"defaults": {"unit": "s"}, "overrides": []},
     "targets": [{"refId": "A", "expr": "route:http_request_duration_seconds:p99_1m", "legendFormat": "{{route}}"}]}
  ]
}
J
echo "Esperando a que haya datos (~1 min)..."
sleep 70
echo "solve.sh completado."
