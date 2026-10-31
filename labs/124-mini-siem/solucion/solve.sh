#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cat > /etc/siem/reglas/deteccion.yml <<'Y'
groups:
  - name: deteccion
    rules:
      - alert: EscaneoWeb
        expr: sum by (host) (count_over_time({job="nginx"} |~ "\" 404 " [5m])) > 5
        for: 0m
        labels: {severity: low, kill_chain: reconocimiento}
        annotations: {summary: "Ráfaga de 404 en {{ $labels.host }} (escaneo de rutas)"}
      - alert: SubidaDeEjecutable
        expr: sum by (host) (count_over_time({job="nginx"} |~ "POST /api/upload\\?name=[^ ]*\\.(sh|php|exe|elf)" [10m])) > 0
        for: 0m
        labels: {severity: high, kill_chain: entrega}
        annotations: {summary: "Subida de un ejecutable a {{ $labels.host }}"}
      - alert: FuerzaBrutaSSH
        expr: sum by (host) (count_over_time({job="auth"} |= "Failed password" [5m])) > 10
        for: 0m
        labels: {severity: high, kill_chain: explotacion}
        annotations: {summary: "Fuerza bruta SSH contra {{ $labels.host }}"}
      - alert: CuentaUID0
        expr: sum by (host) (count_over_time({job="auth"} |~ "useradd.*UID=0" [15m])) > 0
        for: 0m
        labels: {severity: critical, kill_chain: instalacion}
        annotations: {summary: "Cuenta con UID 0 creada en {{ $labels.host }}"}
      - alert: VolcadoYExfiltracion
        expr: sum by (host) (count_over_time({job="auth", host="db-01"} |~ "COMMAND=.*(pg_dump|curl -T)" [15m])) > 0
        for: 0m
        labels: {severity: critical, kill_chain: acciones}
        annotations: {summary: "Volcado de la base de datos y envío fuera en {{ $labels.host }}"}
Y
chmod 644 /etc/siem/reglas/deteccion.yml
cat > /home/analista/soc.md <<'M'
# SOC
- Antivirus: firmas sobre ficheros en un equipo; bloquea lo conocido.
- EDR: agente en el endpoint que registra comportamiento (procesos, red, ficheros) y permite responder (aislar, matar).
- SIEM: centraliza logs de muchas fuentes, correlaciona y alerta (aquí Loki + reglas).
Niveles: N1 triage de alertas; N2 investigación y respuesta; N3 caza de amenazas e ingeniería de detección.
M
chown analista:analista /home/analista/soc.md
for _ in $(seq 1 30); do
  n=$(curl -fs http://loki:3100/prometheus/api/v1/alerts | jq '[.data.alerts[] | select(.state=="firing") | .labels.alertname] | unique | length')
  [ "${n:-0}" -ge 4 ] && break; sleep 5
done
