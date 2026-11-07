#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
C=~/charts/tienda
helm -n prod rollback tienda 1 --wait --timeout 3m

cat > "$C/values.yaml" <<'YML'
replicaCount: 2
mensaje: "Bienvenido a la tienda"
image:
  repository: nginx
  tag: "1.27-alpine"
YML
sed -i 's/^  replicas: 2$/  replicas: {{ .Values.replicaCount }}/' "$C/templates/deployment.yaml"
sed -i 's|<h1>Bienvenido a la tienda</h1>|<h1>{{ .Values.mensaje }}</h1>|' "$C/templates/configmap.yaml"
printf 'replicaCount: 1\nmensaje: "Tienda (staging)"\n' > "$C/values-staging.yaml"
printf 'replicaCount: 2\n' > "$C/values-prod.yaml"
helm lint "$C"
helm upgrade --install tienda "$C" -n staging --create-namespace -f "$C/values-staging.yaml" --wait --timeout 3m
helm -n prod history tienda
echo "solve.sh completado."
