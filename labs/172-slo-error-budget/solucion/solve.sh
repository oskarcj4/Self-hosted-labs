#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cat > ~/slo/slo-rules.yml <<'Y'
groups:
  - name: slo-checkout-sli
    rules:
      - record: slo:sli_error:ratio_rate5m
        expr: |
          sum by (job) (rate(http_requests_total{job="checkout",code=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total{job="checkout"}[5m]))
      - record: slo:sli_error:ratio_rate30m
        expr: |
          sum by (job) (rate(http_requests_total{job="checkout",code=~"5.."}[30m]))
          /
          sum by (job) (rate(http_requests_total{job="checkout"}[30m]))
      - record: slo:sli_error:ratio_rate1h
        expr: |
          sum by (job) (rate(http_requests_total{job="checkout",code=~"5.."}[1h]))
          /
          sum by (job) (rate(http_requests_total{job="checkout"}[1h]))
      - record: slo:sli_error:ratio_rate6h
        expr: |
          sum by (job) (rate(http_requests_total{job="checkout",code=~"5.."}[6h]))
          /
          sum by (job) (rate(http_requests_total{job="checkout"}[6h]))

  - name: slo-checkout-alertas
    rules:
      # SLO 99.5 % en 30 días: presupuesto de error = 0.005.
      # 14.4x durante 1 h consume el 2 % del presupuesto mensual: despierta.
      - alert: CheckoutSLOBurnRateRapida
        expr: |
          slo:sli_error:ratio_rate1h > (14.4 * 0.005)
          and
          slo:sli_error:ratio_rate5m > (14.4 * 0.005)
        for: 2m
        labels:
          severity: page
        annotations:
          summary: "checkout quema presupuesto de error 14.4x (se agota en ~2 días)"
      # 6x durante 6 h consume el 5 % del presupuesto: ticket para hoy.
      - alert: CheckoutSLOBurnRateLenta
        expr: |
          slo:sli_error:ratio_rate6h > (6 * 0.005)
          and
          slo:sli_error:ratio_rate30m > (6 * 0.005)
        for: 15m
        labels:
          severity: ticket
        annotations:
          summary: "checkout quema presupuesto de error 6x (se agota en ~5 días)"
Y
# 30 días = 43200 min; 0.5 % = 216 min. Incidentes: 45 + 30 + 75 = 150 min.
printf 'presupuesto_minutos=216\nrestante_minutos=66\n' > ~/slo/presupuesto.txt
promtool check rules ~/slo/slo-rules.yml
curl -sf -X POST http://127.0.0.1:9090/-/reload
echo "solve.sh completado."
