#!/usr/bin/env bash
# Lab 166: un HPA que nunca escala. El Deployment no declara requests de CPU,
# así que el HPA no puede calcular el % de uso (TARGETS <unknown>). Además no
# tiene ventana de estabilización para bajar: si escalara, oscilaría.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/metrics-server --timeout=300s

kubectl create namespace web
for _ in $(seq 1 60); do kubectl -n web get sa default >/dev/null 2>&1 && break; sleep 1; done
mkdir -p /home/analista/manifiestos
cat > /home/analista/manifiestos/web.yaml <<'YML'
apiVersion: v1
kind: ConfigMap
metadata: {name: web-cgi, namespace: web}
data:
  calcular: |
    #!/bin/sh
    # Cada petición quema CPU un rato (simula un cálculo de precios).
    i=0; while [ $i -lt 30000 ]; do i=$((i+1)); done
    printf 'Content-Type: text/plain\r\n\r\nok\n'
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: web}
spec:
  replicas: 1
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          mkdir -p /www/cgi-bin && cp /cgi/calcular /www/cgi-bin/ && chmod +x /www/cgi-bin/calcular
          echo ok > /www/index.html
          exec httpd -f -p 8080 -h /www
        ports: [{containerPort: 8080}]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 5}
        volumeMounts: [{name: cgi, mountPath: /cgi}]
      volumes:
      - name: cgi
        configMap: {name: web-cgi}
---
apiVersion: v1
kind: Service
metadata: {name: web, namespace: web}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web, namespace: web}
spec:
  scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: web}
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: {type: Utilization, averageUtilization: 50}
---
# Generador de carga: en 0 hasta que quieras probar (kubectl -n web scale deploy carga --replicas=3).
apiVersion: apps/v1
kind: Deployment
metadata: {name: carga, namespace: web}
spec:
  replicas: 0
  selector: {matchLabels: {app: carga}}
  template:
    metadata: {labels: {app: carga}}
    spec:
      containers:
      - name: carga
        image: busybox:1.36
        command: ["sh", "-c", "while :; do wget -q -O /dev/null http://web/cgi-bin/calcular; done"]
        resources:
          requests: {cpu: 10m, memory: 8Mi}
          limits:   {cpu: 200m, memory: 16Mi}
YML
kubectl apply -f /home/analista/manifiestos/web.yaml
kubectl -n web rollout status deploy/web --timeout=180s
chown -R analista:analista /home/analista/manifiestos

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · El autoescalado no escala (namespace web)

En el pico de ayer 'web' se quedó con 1 réplica y el HPA no hizo nada.
Manifiestos: ~/manifiestos/web.yaml

1. Mira el HPA (kubectl -n web get hpa / describe hpa web) y apunta la causa en
   ~/hpa.txt:   causa=<...>
2. Arréglalo: el contenedor de web debe declarar requests de CPU (p. ej. 100m)
   y un límite de memoria.
3. Evita el efecto yo-yo: behavior.scaleDown.stabilizationWindowSeconds >= 60
   en el HPA.
4. Pruébalo: kubectl -n web scale deploy carga --replicas=3 y observa cómo
   sube (kubectl -n web get hpa -w). Luego vuelve a dejar carga en 0.
   El check lanzará su propia carga y esperará a ver >= 2 réplicas.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 166 plantado."
