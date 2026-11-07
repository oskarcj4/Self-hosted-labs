#!/usr/bin/env bash
# Lab 204: Loki + Promtail recién montados. Pagos no llega, el catálogo tiene
# una etiqueta por IP de cliente y las trazas de error llegan troceadas.
set -e
H=/home/analista
mkdir -p /var/log/tienda /etc/loki /etc/promtail /var/lib/loki /var/lib/promtail /opt/tienda $H/consultas

# --- Generador de logs de la tienda -------------------------------------------
cat > /opt/tienda/generador.py <<'PY'
"""Escribe logs de pagos (JSON) y catálogo (texto, con trazas) sin parar."""
import json, random, time, datetime
random.seed()
PAN = ["4111111111111111", "5500005555555559", "4012888888881881", "378282246310005"]
def ahora(): return datetime.datetime.now()
def pagos(f):
    r = random.random()
    nivel = "error" if r < 0.06 else "warn" if r < 0.16 else "info"
    dur = random.randint(1100, 4000) if random.random() < 0.12 else random.randint(40, 900)
    msg = {"error": "cobro rechazado por la pasarela",
           "warn": "reintento de cobro",
           "info": "cobro aceptado"}[nivel]
    linea = {"ts": ahora().isoformat(timespec="milliseconds"), "level": nivel,
             "msg": f"{msg} tarjeta={random.choice(PAN)} importe={random.randint(5, 300)}.{random.randint(0, 99):02d}",
             "pedido": f"P-{random.randint(100000, 999999)}", "user_id": f"u-{random.randint(1000, 99999)}",
             "duration_ms": dur}
    f.write(json.dumps(linea, ensure_ascii=False) + "\n")
def catalogo(f):
    t = ahora().strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]
    ip = f"10.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
    if random.random() < 0.08:
        f.write(f"{t} ERROR catalogo ip={ip} fallo al leer el producto\n"
                "Traceback (most recent call last):\n"
                '  File "/srv/catalogo/app.py", line 88, in producto\n'
                "    precio = float(fila['precio'])\n"
                "ValueError: could not convert string to float: 'N/D'\n")
    else:
        nivel = "WARNING" if random.random() < 0.1 else "INFO"
        f.write(f"{t} {nivel} catalogo ip={ip} GET /productos/{random.randint(1, 500)} 200\n")
with open("/var/log/tienda/pagos.log", "a", buffering=1) as p, \
     open("/var/log/tienda/catalogo.log", "a", buffering=1) as c:
    while True:
        for _ in range(2): pagos(p)
        catalogo(c)
        time.sleep(0.5)
PY
cat > /etc/systemd/system/tienda-logs.service <<'U'
[Unit]
Description=Tienda: aplicaciones que escriben logs (pagos y catálogo)
[Service]
ExecStart=/usr/bin/python3 /opt/tienda/generador.py
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Loki ---------------------------------------------------------------------
cat > /etc/loki/loki.yml <<'Y'
auth_enabled: false
server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: warn
common:
  instance_addr: 127.0.0.1
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
limits_config:
  allow_structured_metadata: true
analytics:
  reporting_enabled: false
Y
cat > /etc/systemd/system/loki.service <<'U'
[Unit]
Description=Loki
After=network.target
[Service]
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yml
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Promtail (con los fallos) ------------------------------------------------
cat > /etc/promtail/config.yml <<'Y'
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  log_level: warn
positions:
  filename: /var/lib/promtail/positions.yaml
clients:
  - url: http://127.0.0.1:3100/loki/api/v1/push

scrape_configs:
  - job_name: pagos
    static_configs:
      - targets: [localhost]
        labels:
          app: pagos
          __path__: /var/log/tienda/pagos/*.log
    pipeline_stages:
      - json:
          expressions:
            nivel: level
            pedido: pedido
            user_id: user_id
      - labels:
          nivel:
          pedido:
          user_id:

  - job_name: catalogo
    static_configs:
      - targets: [localhost]
        labels:
          app: catalogo
          __path__: /var/log/tienda/catalogo.log
    pipeline_stages:
      - regex:
          expression: '^\S+ \S+ (?P<nivel>[A-Z]+) catalogo ip=(?P<ip>\S+)'
      - labels:
          nivel:
          ip:
Y
chmod 0644 /etc/promtail/config.yml
cat > /etc/systemd/system/promtail.service <<'U'
[Unit]
Description=Promtail
After=loki.service
[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always
[Install]
WantedBy=multi-user.target
U

systemctl daemon-reload
systemctl enable --now loki tienda-logs >/dev/null 2>&1
for i in $(seq 1 60); do curl -sf http://127.0.0.1:3100/ready >/dev/null && break; sleep 2; done
curl -sf http://127.0.0.1:3100/ready >/dev/null
systemctl enable --now promtail >/dev/null 2>&1
sleep 10

chown -R analista:analista $H/consultas
cat >> $H/.bashrc <<'B'
export LOKI_ADDR=http://127.0.0.1:3100
B
cat > $H/TAREA.txt <<'TXT'
TAREA · Logs con Loki

Loki (:3100) y Promtail están recién montados para la tienda, pero:
  - De pagos (/var/log/tienda/pagos.log, JSON) no llega nada.
  - El catálogo crea un stream nuevo por cada IP de cliente.
  - Las trazas de error de Python llegan troceadas: una entrada por línea.

Arregla /etc/promtail/config.yml (sudo) y reinicia promtail:

1. Pagos llega a Loki. Antes de enviarlo: los mensajes llevan números de
   tarjeta completos. Enmascáralos en Promtail para que en Loki sólo quede
   tarjeta=****<últimos 4 dígitos> (cualquier número de asteriscos).
2. Etiquetas con baja cardinalidad: app y nivel (en los dos). Nada de
   pedido, user_id, ip ni otras con miles de valores: eso va en la línea y
   se filtra con | json o | logfmt al consultar.
3. Cada error del catálogo con su traza es UNA entrada (multiline).
4. Consultas LogQL en ~/consultas/:
     pagos-lentos.logql   líneas de pagos con duration_ms > 1000
     errores-por-app.logql   nº de entradas de nivel error en el último
                             minuto, por app (consulta de métrica)

  logcli query '{app="catalogo"}' --since=1m
  logcli series '{}' --since=1m --analyze-labels

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 204 plantado."
