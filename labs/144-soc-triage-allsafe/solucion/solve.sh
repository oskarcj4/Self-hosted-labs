#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
F=/var/log/soc/alertas.jsonl
REALES=$(jq -r 'select(.nivel>=10).id' "$F" | sort | paste -sd,)
cat > $H/triage.txt <<T
ip_atacante=203.0.113.7
alertas_reales=$REALES
regla_ruidosa=healthcheck_http
T
chown analista:analista $H/triage.txt
grep -qx 'healthcheck_http' /etc/soc/supresiones.txt 2>/dev/null || echo 'healthcheck_http' >> /etc/soc/supresiones.txt
echo "solve.sh completado. alertas_reales=$REALES"
