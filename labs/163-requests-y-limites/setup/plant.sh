#!/usr/bin/env bash
# Lab 163: requests, límites y clases de QoS.
#  - api: sin resources (BestEffort): es lo primero que se desaloja.
#  - calc: límite de CPU 20m -> estrangulado (CFS throttling): cada trabajo tarda 20x.
#  - scraper: BestEffort a propósito (tarea prescindible).
#  - el namespace no tiene LimitRange: cualquier pod nuevo nace BestEffort.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/metrics-server --timeout=300s || true

kubectl create namespace catalogo
for _ in $(seq 1 60); do kubectl -n catalogo get sa default >/dev/null 2>&1 && break; sleep 1; done
mkdir -p /home/analista/manifiestos
cat > /home/analista/manifiestos/catalogo.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: catalogo}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: calc, namespace: catalogo}
spec:
  replicas: 1
  selector: {matchLabels: {app: calc}}
  template:
    metadata: {labels: {app: calc}}
    spec:
      containers:
      - name: calc
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          n=0
          while :; do
            n=$((n+1)); t0=$(date +%s); i=0
            while [ $i -lt 150000 ]; do i=$((i+1)); done
            echo "trabajo $n: $(( $(date +%s) - t0 )) s"
            sleep 3
          done
        resources:
          requests: {cpu: 20m, memory: 32Mi}
          limits:   {cpu: 20m, memory: 32Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: scraper, namespace: catalogo}
spec:
  replicas: 1
  selector: {matchLabels: {app: scraper}}
  template:
    metadata: {labels: {app: scraper}}
    spec:
      containers:
      - name: scraper
        image: busybox:1.36
        command: ["sh", "-c", "while :; do echo raspando precios de la competencia; sleep 30; done"]
YML
kubectl apply -f /home/analista/manifiestos/catalogo.yaml
kubectl -n catalogo rollout status deploy/api --timeout=180s
kubectl -n catalogo rollout status deploy/calc --timeout=180s
chown -R analista:analista /home/analista/manifiestos

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Requests, límites y QoS (namespace catalogo)

Quejas: "calc va lentísimo aunque el nodo está ocioso" y "anoche, con el nodo
corto de memoria, se cayó la api y el scraper siguió vivo".
Manifiestos: ~/manifiestos/catalogo.yaml

1. ~/qos.txt con la clase QoS que tiene AHORA cada pod y tu análisis:
     api=<BestEffort|Burstable|Guaranteed>
     calc=<...>
     scraper=<...>
     estrangulado=<pod con CPU throttling>
2. api es crítica: que sea Guaranteed (requests = limits en cpu y memoria).
3. calc: quítale el estrangulamiento (límite de CPU >= 500m o sin límite de
   CPU), manteniendo un request de CPU >= 100m. Compara los tiempos en sus logs.
4. LimitRange "defaults" en catalogo con default y defaultRequest de cpu y
   memoria: así ningún pod nuevo nace BestEffort por olvido.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 163 plantado."
