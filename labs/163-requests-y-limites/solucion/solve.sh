#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
printf 'api=BestEffort\ncalc=Guaranteed\nscraper=BestEffort\nestrangulado=calc\n' > ~/qos.txt
kubectl -n catalogo set resources deploy api \
  --requests=cpu=100m,memory=64Mi --limits=cpu=100m,memory=64Mi
# Límite de CPU fuera (o alto); request realista. Memoria con techo.
kubectl -n catalogo patch deploy calc --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources",
   "value":{"requests":{"cpu":"200m","memory":"16Mi"},"limits":{"memory":"32Mi"}}}]'
kubectl apply -f - <<'YML'
apiVersion: v1
kind: LimitRange
metadata: {name: defaults, namespace: catalogo}
spec:
  limits:
  - type: Container
    defaultRequest: {cpu: 50m, memory: 32Mi}
    default:        {cpu: 500m, memory: 128Mi}
YML
kubectl -n catalogo rollout status deploy api --timeout=180s
kubectl -n catalogo rollout status deploy calc --timeout=180s
kubectl -n catalogo get pods -o custom-columns=POD:.metadata.name,QOS:.status.qosClass
echo "solve.sh completado."
