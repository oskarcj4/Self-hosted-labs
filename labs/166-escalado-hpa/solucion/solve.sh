#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "causa=faltan requests de cpu en el contenedor: el HPA no puede calcular el porcentaje" > ~/hpa.txt
kubectl -n web set resources deploy web --requests=cpu=100m,memory=16Mi --limits=memory=64Mi
kubectl -n web patch hpa web --type=merge -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":120}}}}'
kubectl -n web rollout status deploy web --timeout=180s
kubectl -n web get hpa
echo "solve.sh completado."
