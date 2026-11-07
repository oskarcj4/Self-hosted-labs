#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
printf 'api=oomkilled\nworker=liveness\nweb=configmap\n' > ~/diagnostico.txt
kubectl -n tienda patch deploy api --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"96Mi"}]'
kubectl -n tienda patch deploy worker --type=json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/port","value":8080}]'
kubectl -n tienda create configmap web-config --from-literal=DB_HOST=db.tienda.svc.cluster.local \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n tienda rollout restart deploy web
kubectl -n tienda rollout status deploy api --timeout=180s
kubectl -n tienda rollout status deploy worker --timeout=180s
kubectl -n tienda rollout status deploy web --timeout=180s
echo "solve.sh completado."
