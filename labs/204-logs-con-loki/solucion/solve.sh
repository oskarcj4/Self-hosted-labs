#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
sudo tee /etc/promtail/config.yml >/dev/null <<'Y'
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
          __path__: /var/log/tienda/pagos.log
    pipeline_stages:
      # Antes que nada: fuera los números de tarjeta (sólo quedan los 4 últimos).
      - replace:
          expression: 'tarjeta=(\d{8,15})\d{4}\b'
          replace: '****'
      - json:
          expressions:
            nivel: level
      # Sólo el nivel como etiqueta; pedido, user_id y duration_ms siguen en la línea.
      - labels:
          nivel:

  - job_name: catalogo
    static_configs:
      - targets: [localhost]
        labels:
          app: catalogo
          __path__: /var/log/tienda/catalogo.log
    pipeline_stages:
      # Una entrada empieza por fecha; lo demás (la traza) se pega a la anterior.
      - multiline:
          firstline: '^\d{4}-\d{2}-\d{2} '
          max_wait_time: 3s
      - regex:
          expression: '^\S+ \S+ (?P<nivel>[A-Z]+) catalogo'
      - template:
          source: nivel
          template: '{{ ToLower .Value }}'
      - labels:
          nivel:
Y
sudo systemctl restart promtail

cat > ~/consultas/pagos-lentos.logql <<'Q'
{app="pagos"} | json | duration_ms > 1000
Q
cat > ~/consultas/errores-por-app.logql <<'Q'
sum by (app) (count_over_time({app=~".+", nivel="error"}[1m]))
Q
echo "Esperando un minuto de logs con la configuración nueva..."
sleep 70
export LOKI_ADDR=http://127.0.0.1:3100
logcli series '{app=~".+"}' --since=30s --analyze-labels 2>/dev/null | head -12 || true
echo "solve.sh completado."
