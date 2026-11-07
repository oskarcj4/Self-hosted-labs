#!/usr/bin/env bash
# Lab 161: tres Deployments en CrashLoopBackOff por tres causas distintas.
#  - api:    límite de memoria (32Mi) por debajo de lo que carga al arrancar -> OOMKilled.
#  - worker: livenessProbe apunta al puerto equivocado -> kubelet lo mata en bucle.
#  - web:    falta el ConfigMap web-config (DB_HOST) -> la app sale con error.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done
mkdir -p /home/analista/manifiestos
cat > /home/analista/manifiestos/tienda.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: tienda, labels: {app: api}}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-ec"]
        args:
        - |
          echo "Cargando el catálogo en memoria (~60 MiB)..."
          head -c 60m /dev/zero | tail > /dev/null
          echo "Catálogo cargado. Sirviendo en :8080"
          mkdir -p /www && echo ok > /www/index.html
          exec httpd -f -p 8080 -h /www
        ports: [{containerPort: 8080}]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 3}
        resources:
          requests: {cpu: 50m, memory: 32Mi}
          limits:   {cpu: 200m, memory: 32Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: worker, namespace: tienda, labels: {app: worker}}
spec:
  replicas: 1
  selector: {matchLabels: {app: worker}}
  template:
    metadata: {labels: {app: worker}}
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          mkdir -p /www && echo ok > /www/healthz
          echo "worker escuchando en :8080 (salud en /healthz)"
          exec httpd -f -p 8080 -h /www
        ports: [{containerPort: 8080}]
        readinessProbe: {httpGet: {path: /healthz, port: 8080}, periodSeconds: 3}
        livenessProbe:
          httpGet: {path: /healthz, port: 8081}
          initialDelaySeconds: 3
          periodSeconds: 3
          failureThreshold: 2
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {cpu: 100m, memory: 64Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: tienda, labels: {app: web}}
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
          [ -n "$DB_HOST" ] || { echo "FATAL: falta la variable DB_HOST (se espera del ConfigMap web-config)"; exit 1; }
          echo "web conectando a $DB_HOST"
          mkdir -p /www && echo "db=$DB_HOST" > /www/index.html
          exec httpd -f -p 8080 -h /www
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef: {name: web-config, key: DB_HOST, optional: true}
        ports: [{containerPort: 8080}]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 3}
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {cpu: 100m, memory: 64Mi}
YML
kubectl apply -f /home/analista/manifiestos/tienda.yaml
# Que los tres lleguen a fallar al menos una vez antes de abrir el lab.
for _ in $(seq 1 90); do
  n=$(kubectl -n tienda get pods -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$1>=1' | wc -l)
  [ "$n" -ge 3 ] && break; sleep 2
done
chown -R analista:analista /home/analista/manifiestos

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pods en CrashLoopBackOff (namespace tienda)

Tras el despliegue de anoche, api, worker y web reinician sin parar.
Los manifiestos están en ~/manifiestos/tienda.yaml.

1. Diagnostica cada uno y escribe la causa en ~/diagnostico.txt:
     api=<causa>
     worker=<causa>
     web=<causa>
   (palabras clave: oomkilled / liveness / configmap)
2. Arregla los tres sin quitarles su trabajo:
   - api necesita ~60 MiB al arrancar: dale memoria suficiente.
   - worker: la sonda debe mirar donde la app escucha de verdad.
   - web: crea el ConfigMap web-config con DB_HOST=db.tienda.svc.cluster.local
3. Los tres Ready y sin reinicios nuevos.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 161 plantado."
