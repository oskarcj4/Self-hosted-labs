#!/usr/bin/env bash
# Lab 124: mini SIEM. Tres servidores mandan logs a Loki por promtail; el SOC
# (tú) escribe reglas de detección para el ruler de Loki y las mapea a la
# Cyber Kill Chain.
set -e
echo 'export LOKI_ADDR=http://loki:3100' > /etc/profile.d/loki.sh
chmod 1777 /etc/siem/reglas
mkdir -p /home/analista/siem
cat > /home/analista/siem/ejemplo-regla.yml <<'Y'
# Plantilla: copia a /etc/siem/reglas/deteccion.yml y añade tus reglas.
# Loki recarga el directorio cada ~15 s.
groups:
  - name: deteccion
    rules:
      - alert: EjemploErrores5xx
        expr: sum by (host) (count_over_time({job="nginx"} |~ "\" 5[0-9][0-9] " [5m])) > 20
        for: 0m
        labels:
          severity: medium
          kill_chain: acciones        # fase de la Cyber Kill Chain
        annotations:
          summary: "Muchos 5xx en {{ $labels.host }}"
Y
cat > /home/analista/siem/LEEME.txt <<'TXT'
Fuentes (etiquetas en Loki):
  {job="nginx", host="web-01"}   access.log de la web
  {job="auth",  host="ssh-01"}   auth.log del bastión SSH
  {job="auth",  host="db-01"}    auth.log de la base de datos
Consultas:  logcli query '{job="auth"} |= "Failed password"' --since=10m
Reglas:     /etc/siem/reglas/*.yml   (las lee el ruler de Loki)
Estado:     curl -s $LOKI_ADDR/prometheus/api/v1/rules | jq
            curl -s $LOKI_ADDR/prometheus/api/v1/alerts | jq
Grafana:    http://127.0.0.1:3124 (Explore → Loki), opcional
TXT
chown -R analista:analista /home/analista/siem
for _ in $(seq 1 60); do curl -fs http://loki:3100/ready >/dev/null 2>&1 && break; sleep 2; done
echo "Lab 124 plantado."
