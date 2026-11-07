#!/usr/bin/env bash
# Lab 164: Helm.
#  - Release 'tienda' en prod: revisión 1 buena; revisión 2 (upgrade de anoche)
#    con una imagen que no existe -> ImagePullBackOff. Hay que hacer rollback.
#  - El chart del repo (~/charts/tienda) tiene réplicas y mensaje fijos: hay que
#    parametrizarlo y crear valores por ambiente para desplegar staging.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export HOME=/root
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

H=/home/analista
C=$H/charts/tienda
mkdir -p "$C/templates"
cat > "$C/Chart.yaml" <<'YML'
apiVersion: v2
name: tienda
description: Frontal de la tienda (nginx con una página de bienvenida)
type: application
version: 0.1.0
appVersion: "1.27"
YML
cat > "$C/values.yaml" <<'YML'
image:
  repository: nginx
  tag: "1.27-alpine"
YML
cat > "$C/templates/_helpers.tpl" <<'TPL'
{{- define "tienda.labels" -}}
app.kubernetes.io/name: tienda
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
TPL
cat > "$C/templates/configmap.yaml" <<'YML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-web
  labels: {{- include "tienda.labels" . | nindent 4 }}
data:
  index.html: |
    <h1>Bienvenido a la tienda</h1>
YML
cat > "$C/templates/deployment.yaml" <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-web
  labels: {{- include "tienda.labels" . | nindent 4 }}
spec:
  replicas: 2
  selector:
    matchLabels: {{- include "tienda.labels" . | nindent 6 }}
  template:
    metadata:
      labels: {{- include "tienda.labels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      containers:
      - name: web
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports: [{containerPort: 80}]
        readinessProbe: {httpGet: {path: /, port: 80}, periodSeconds: 3}
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {memory: 64Mi}
        volumeMounts: [{name: html, mountPath: /usr/share/nginx/html}]
      volumes:
      - name: html
        configMap: {name: {{ .Release.Name }}-web}
YML
cat > "$C/templates/service.yaml" <<'YML'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-web
  labels: {{- include "tienda.labels" . | nindent 4 }}
spec:
  selector: {{- include "tienda.labels" . | nindent 4 }}
  ports: [{port: 80, targetPort: 80}]
YML

# prod: revisión 1 buena; revisión 2 rota (tag inexistente).
helm install tienda "$C" -n prod --create-namespace --wait --timeout 5m
helm upgrade tienda "$C" -n prod --set image.tag=1.29-alpine-rc1 --description "Upgrade a nginx 1.29 (rc)"
sleep 20

chown -R analista:analista "$H/charts"
runuser -u analista -- git -C "$H/charts" init -q -b main
runuser -u analista -- git -C "$H/charts" -c user.name=ops -c user.email=ops@tienda.local add -A
runuser -u analista -- git -C "$H/charts" -c user.name=ops -c user.email=ops@tienda.local commit -qm "Chart tienda 0.1.0"

cat > $H/TAREA.txt <<'TXT'
TAREA · Helm: rollback en prod y chart por ambiente

1. prod está medio caído desde el upgrade de anoche (helm -n prod history tienda).
   Vuelve a la última revisión buena con helm rollback.
2. El chart ~/charts/tienda tiene valores fijos en las plantillas. Parametriza:
     replicaCount   -> spec.replicas            (por defecto 2)
     mensaje        -> el texto del index.html  (por defecto "Bienvenido a la tienda")
   Debe pasar 'helm lint'.
3. Crea ~/charts/tienda/values-staging.yaml (replicaCount: 1, mensaje con la
   palabra "staging") y ~/charts/tienda/values-prod.yaml (replicaCount: 2).
4. Instala la release 'tienda' en el namespace staging con values-staging.yaml.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 164 plantado."
