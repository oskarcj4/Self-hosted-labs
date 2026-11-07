#!/usr/bin/env bash
# Lab 199: hay que actualizar el clúster de v1.31 a v1.32 y los manifiestos
# usan una API que v1.32 elimina (flowcontrol.apiserver.k8s.io/v1beta3).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done

M=/home/analista/manifiestos
mkdir -p $M
cat > $M/tienda.yaml <<'YML'
apiVersion: v1
kind: ServiceAccount
metadata: {name: despliegue, namespace: tienda}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: tienda, namespace: tienda}
spec:
  replicas: 2
  selector: {matchLabels: {app: tienda}}
  template:
    metadata: {labels: {app: tienda}}
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        readinessProbe: {httpGet: {path: /, port: 80}, periodSeconds: 3}
        resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 64Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: tienda, namespace: tienda}
spec:
  selector: {app: tienda}
  ports: [{port: 80, targetPort: 80}]
YML
cat > $M/prioridad-ci.yaml <<'YML'
# Que el CI no pueda saturar el API server: sus peticiones van a una cola
# con prioridad limitada (API Priority and Fairness).
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata: {name: ci-lotes}
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 10
    limitResponse:
      type: Queue
      queuing: {queues: 16, handSize: 4, queueLengthLimit: 50}
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata: {name: ci-lotes}
spec:
  priorityLevelConfiguration: {name: ci-lotes}
  matchingPrecedence: 1000
  distinguisherMethod: {type: ByUser}
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount: {name: despliegue, namespace: tienda}
    resourceRules:
    - {verbs: ["*"], apiGroups: ["*"], resources: ["*"], namespaces: ["*"]}
YML
kubectl apply -f $M/ 2>&1 | grep -v '^Warning' || true
kubectl -n tienda rollout status deploy/tienda --timeout=180s
chown -R analista:analista $M

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Actualizar Kubernetes de v1.31 a v1.32

El clúster (k3s v1.31.4) tiene que pasar a v1.32.0. El binario nuevo ya está
descargado, con su lista de sumas:

  /opt/k3s/v1.32.0/k3s
  /opt/k3s/v1.32.0/sha256sum-amd64.txt

(sus imágenes de sistema ya están en el nodo: no hace falta red).

Procedimiento que hay que seguir, en este orden:
  1. Antes de tocar nada, revisa que los manifiestos (~/manifiestos/) no
     usen APIs que v1.32 ELIMINA, y migra las que haya. Busca en las notas
     de deprecación de Kubernetes, o pregunta al propio clúster:
       kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
  2. Copia de seguridad del estado del clúster ANTES de actualizar. k3s
     guarda el estado en SQLite: /var/lib/rancher/k3s/server/db/state.db.
     Déjala en /var/backups/k3s/ (copia consistente: es una base de datos
     en uso).
  3. Verifica el binario nuevo contra su sha256 y sustituye
     /usr/local/bin/k3s. Reinicia el servicio k3s.
  4. Comprueba que el nodo está en v1.32.0, que la tienda sigue sirviendo
     y que tus manifiestos se siguen aplicando sin errores.

Todo con sudo (el usuario analista lo tiene).
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 199 plantado."
