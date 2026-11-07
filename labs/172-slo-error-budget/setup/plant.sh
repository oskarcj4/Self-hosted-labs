#!/usr/bin/env bash
# Lab 172: el checkout tiene un SLO de disponibilidad del 99.5 % en 30 días, pero
# la única alerta es "más de 0.5 % de errores durante 1 minuto": suena cada
# noche por picos de segundos y nadie la mira. El alumno escribe SLIs como
# recording rules y alertas multiventana por tasa de consumo (burn rate), y
# calcula el presupuesto de error. check.sh pasa tests ocultos con promtool.
set -e
H=/home/analista
install -d -m 0700 /opt/lab/tests
install -m 0600 /opt/lab/setup/tests/slo.test.yml /opt/lab/tests/slo.test.yml
install -m 0755 /opt/lab/setup/normaliza-reglas.py /opt/lab/normaliza-reglas.py

# --- El servicio checkout (expone métricas tipo Prometheus) ----------------------
cat > /usr/local/bin/checkout-sim <<'PY'
#!/usr/bin/env python3
"""Simula el tráfico del checkout: ~20 peticiones/s, ~0.3 % de errores 5xx."""
import random, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
c = {"200": 0, "500": 0, "503": 0}
def trafico():
    while True:
        for _ in range(20):
            r = random.random()
            c["500" if r < 0.002 else "503" if r < 0.003 else "200"] += 1
        time.sleep(1)
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        out = "# TYPE http_requests_total counter\n" + "".join(
            f'http_requests_total{{code="{k}",handler="/checkout"}} {v}\n' for k, v in c.items())
        b = out.encode()
        self.send_response(200); self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
threading.Thread(target=trafico, daemon=True).start()
ThreadingHTTPServer(("127.0.0.1", 9100), H).serve_forever()
PY
chmod 0755 /usr/local/bin/checkout-sim
cat > /etc/systemd/system/checkout.service <<'U'
[Unit]
Description=checkout (simulado)
[Service]
ExecStart=/usr/local/bin/checkout-sim
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Prometheus -------------------------------------------------------------------
mkdir -p /etc/prometheus /var/lib/prometheus $H/slo
cat > /etc/prometheus/prometheus.yml <<'Y'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - /home/analista/slo/*-rules.yml
scrape_configs:
  - job_name: checkout
    static_configs: [{targets: ["127.0.0.1:9100"]}]
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

cat > $H/slo/slo-rules.yml <<'Y'
groups:
  - name: checkout
    rules:
      # "Si hay más de 0.5 % de errores, avisa". Suena todas las noches.
      - alert: CheckoutErrores
        expr: |
          sum(rate(http_requests_total{job="checkout",code=~"5.."}[1m]))
          /
          sum(rate(http_requests_total{job="checkout"}[1m])) > 0.005
        for: 1m
        labels:
          severity: page
        annotations:
          summary: "checkout con errores"
Y
cat > $H/slo/SLO.md <<'TXT'
# SLO · checkout

- SLI: proporción de peticiones con respuesta 5xx
  (http_requests_total{job="checkout",code=~"5.."} / todas).
- Objetivo: 99.5 % de peticiones correctas, ventana móvil de 30 días.
- Presupuesto de error: lo que sobra hasta el 100 %.

Política: despertar a alguien (severity=page) sólo si el ritmo de errores
agota el presupuesto en días; si lo agota en semanas, ticket (severity=ticket).
TXT
cat > $H/slo/incidentes.txt <<'TXT'
Incidentes del checkout en los últimos 30 días (caída total, 100 % de errores):
- 2026-10-12  despliegue con migración rota ............ 45 min
- 2026-10-21  certificado TLS caducado ................. 30 min
- 2026-11-02  base de datos sin espacio en disco ....... 75 min
Fuera de estas ventanas, los errores fueron despreciables.
TXT
chown -R analista:analista $H/slo
systemctl daemon-reload
systemctl enable --now checkout prometheus
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:9090/-/ready >/dev/null && break; sleep 1; done

cat > $H/TAREA.txt <<'TXT'
TAREA · SLO y presupuesto de error (~/slo)

La alerta CheckoutErrores suena cada noche por picos de segundos y nadie la
mira. Lee ~/slo/SLO.md y sustitúyela por alertas basadas en el SLO.

1. En ~/slo/slo-rules.yml, recording rules con el ratio de errores del
   checkout agrupado SÓLO por job (sum by (job)):
     slo:sli_error:ratio_rate5m   slo:sli_error:ratio_rate30m
     slo:sli_error:ratio_rate1h   slo:sli_error:ratio_rate6h
2. Alertas multiventana por tasa de consumo (burn rate), etiqueta severity:
     CheckoutSLOBurnRateRapida  severity=page    14.4x en 1h Y en 5m   (for <= 5m)
     CheckoutSLOBurnRateLenta   severity=ticket  6x    en 6h Y en 30m  (for <= 30m)
   Elimina CheckoutErrores.
3. ~/slo/presupuesto.txt:
     presupuesto_minutos=<minutos de caída total que permite el SLO en 30 días>
     restante_minutos=<lo que queda tras los incidentes de ~/slo/incidentes.txt>
4. Que Prometheus cargue las reglas nuevas (sin reiniciar el servicio).

Valida:     promtool check rules ~/slo/slo-rules.yml
Comprueba:  bash /opt/lab/check.sh   (pasa tests ocultos con promtool test rules)
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 172 plantado."
