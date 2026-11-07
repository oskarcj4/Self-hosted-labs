#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
A=~/app
mkdir -p $A/base $A/overlays/dev $A/overlays/prod

# --- base: todo lo común, una sola vez, sin namespace ---
cat > $A/base/deployment.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels: {app: web}
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        env:
        - name: LOG_LEVEL
          valueFrom: {configMapKeyRef: {name: web-config, key: LOG_LEVEL}}
        readinessProbe:
          httpGet: {path: /, port: 80}
          periodSeconds: 5
        resources:
          requests: {cpu: 10m, memory: 16Mi}
          limits: {memory: 64Mi}
        volumeMounts:
        - {name: html, mountPath: /usr/share/nginx/html}
      volumes:
      - name: html
        configMap:
          name: web-config
          items: [{key: index.html, path: index.html}]
YML
cat > $A/base/service.yaml <<'YML'
apiVersion: v1
kind: Service
metadata:
  name: web
  labels: {app: web}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
YML
cat > $A/base/kustomization.yaml <<'YML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
YML

# --- overlays: sólo las diferencias ---
overlay(){
  local e=$1 r=$2 m=$3 l=$4
  cat > $A/overlays/$e/kustomization.yaml <<YML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $e
resources:
- ../../base
# La etiqueta va a metadatos y pods, NO al selector (es inmutable).
labels:
- pairs: {entorno: $e}
  includeSelectors: false
  includeTemplates: true
replicas:
- {name: web, count: $r}
configMapGenerator:
- name: web-config
  literals:
  - LOG_LEVEL=$l
  - index.html=web entorno=$e
patches:
- path: memoria.yaml
YML
  cat > $A/overlays/$e/memoria.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  template:
    spec:
      containers:
      - name: nginx
        resources:
          limits: {memory: $m}
YML
}
overlay dev 1 64Mi debug
overlay prod 3 128Mi info

kubectl kustomize $A/overlays/prod >/dev/null
for e in dev prod; do
  kubectl apply -k $A/overlays/$e
  kubectl -n $e rollout status deploy/web --timeout=180s
  kubectl -n $e delete configmap web-config --ignore-not-found   # la vieja, sin hash
done
rm -rf $A/dev $A/prod
probar-web
echo "solve.sh completado."
