#!/usr/bin/env bash
# Lab 171: la tienda sólo expone un contador total sin etiquetas, Prometheus
# rasca el puerto equivocado y no hay panel. El alumno instrumenta con RED
# (Rate, Errors, Duration), arregla el scrape, escribe recording rules y
# provisiona un dashboard de Grafana.
set -e
H=/home/analista

# --- La aplicación -----------------------------------------------------------------
mkdir -p $H/app $H/red/dashboards
cat > $H/app/app.py <<'PY'
#!/usr/bin/env python3
"""Tienda: /productos (rápido), /buscar (lento), /pagar (falla a veces).
Sirve en :8080 y expone métricas Prometheus en :8000/metrics."""
import random, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from prometheus_client import Counter, start_http_server

PETICIONES = Counter("peticiones", "Peticiones recibidas")


def productos():
    time.sleep(random.uniform(0.005, 0.03))
    return 200, b'["camiseta", "taza", "gorra"]'


def buscar():
    time.sleep(random.uniform(0.1, 0.6))
    return 200, b'{"resultados": 3}'


def pagar():
    time.sleep(random.uniform(0.02, 0.1))
    if random.random() < 0.1:
        return 500, b'{"error": "pasarela no responde"}'
    return 200, b'{"ok": true}'


RUTAS = {"/productos": productos, "/buscar": buscar, "/pagar": pagar}


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        PETICIONES.inc()
        fn = RUTAS.get(self.path.split("?")[0])
        code, body = fn() if fn else (404, b"no existe")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    start_http_server(8000)
    ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
cat > /usr/local/bin/carga-tienda <<'PY'
#!/usr/bin/env python3
"""Tráfico constante contra la tienda."""
import threading, time, urllib.request, urllib.error
def bucle(ruta, pausa):
    while True:
        try:
            urllib.request.urlopen("http://127.0.0.1:8080" + ruta, timeout=5).read()
        except Exception:
            pass
        time.sleep(pausa)
for ruta, pausa, n in (("/productos", 0.1, 2), ("/buscar", 0.2, 2), ("/pagar", 0.1, 2)):
    for _ in range(n):
        threading.Thread(target=bucle, args=(ruta, pausa), daemon=True).start()
while True:
    time.sleep(60)
PY
chmod 0755 /usr/local/bin/carga-tienda
chown -R analista:analista $H/app $H/red
cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda (app de ejemplo)
[Service]
User=analista
ExecStart=/usr/bin/python3 /home/analista/app/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /etc/systemd/system/carga.service <<'U'
[Unit]
Description=Generador de tráfico para la tienda
After=tienda.service
[Service]
ExecStart=/usr/local/bin/carga-tienda
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Prometheus ------------------------------------------------------------------------
mkdir -p /etc/prometheus /var/lib/prometheus
cat > /etc/prometheus/prometheus.yml <<'Y'
global:
  scrape_interval: 5s
  evaluation_interval: 5s
rule_files:
  - /home/analista/red/*-rules.yml
scrape_configs:
  - job_name: tienda
    static_configs:
      - targets: ["127.0.0.1:8080"]
Y
cat > /etc/systemd/system/prometheus.service <<'U'
[Unit]
Description=Prometheus
After=network.target
[Service]
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus --web.listen-address=127.0.0.1:9090 --web.enable-lifecycle
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Grafana ------------------------------------------------------------------------------
useradd -r -s /usr/sbin/nologin grafana
mkdir -p /opt/grafana/conf/provisioning/datasources /opt/grafana/conf/provisioning/dashboards /var/lib/grafana
cat > /opt/grafana/conf/provisioning/datasources/prometheus.yml <<'Y'
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
Y
cat > /opt/grafana/conf/provisioning/dashboards/tienda.yml <<'Y'
apiVersion: 1
providers:
  - name: tienda
    type: file
    updateIntervalSeconds: 10
    options:
      path: /home/analista/red/dashboards
Y
chown -R grafana:grafana /var/lib/grafana /opt/grafana/data 2>/dev/null || chown -R grafana:grafana /var/lib/grafana
chmod 0755 $H
cat > /etc/systemd/system/grafana.service <<'U'
[Unit]
Description=Grafana
After=network.target prometheus.service
[Service]
User=grafana
WorkingDirectory=/opt/grafana
Environment=GF_PATHS_DATA=/var/lib/grafana GF_PATHS_LOGS=/var/lib/grafana/log
Environment=GF_PATHS_PROVISIONING=/opt/grafana/conf/provisioning
Environment=GF_SERVER_HTTP_ADDR=127.0.0.1 GF_SECURITY_ADMIN_PASSWORD=tienda
Environment=GF_ANALYTICS_REPORTING_ENABLED=false GF_ANALYTICS_CHECK_FOR_UPDATES=false
Environment=GF_NEWS_NEWS_FEED_ENABLED=false GF_PLUGINS_PREINSTALL_DISABLED=true
ExecStart=/opt/grafana/bin/grafana server --homepath /opt/grafana
Restart=always
[Install]
WantedBy=multi-user.target
U

systemctl daemon-reload
systemctl enable --now tienda carga prometheus grafana
for _ in $(seq 1 60); do curl -sf http://127.0.0.1:3000/api/health >/dev/null && break; sleep 2; done

cat > $H/TAREA.txt <<'TXT'
TAREA · Métricas RED para la tienda

Hoy la tienda (~/app/app.py) sólo cuenta "peticiones" en total. Si /pagar
falla o /buscar va lento, nadie lo ve.

1. Instrumenta la app con RED:
     http_requests_total{route, code}              Counter   (Rate y Errors)
     http_request_duration_seconds{route}          Histogram (Duration)
   Reinicia:  sudo systemctl restart tienda
2. Prometheus no rasca bien la app (mira Status > Targets o la API).
   Arregla /etc/prometheus/prometheus.yml y recarga.
3. Recording rules en ~/red/red-rules.yml, por ruta (sum by (route)):
     route:http_requests:rate1m
     route:http_errors:ratio_rate1m
     route:http_request_duration_seconds:p99_1m
4. Dashboard de Grafana "RED tienda" en ~/red/dashboards/red.json con
   (al menos) tres paneles que usen esas tres reglas.

Prometheus: http://127.0.0.1:9090    Grafana: http://127.0.0.1:3000 (admin / tienda)
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 171 plantado."
