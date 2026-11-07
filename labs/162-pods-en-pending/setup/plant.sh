#!/usr/bin/env bash
# Lab 162: pods en Pending por cuatro motivos del scheduler.
#  - taint mantenimiento=si:NoSchedule olvidado en el nodo (afecta a todos).
#  - reportes pide 64 CPU.
#  - cache exige nodeSelector disktype=ssd y el nodo no tiene esa etiqueta.
#  - db usa un PVC con una StorageClass que no existe (rapido-ssd).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl -n kube-system rollout status deploy/local-path-provisioner --timeout=300s

kubectl create namespace erp
for _ in $(seq 1 60); do kubectl -n erp get sa default >/dev/null 2>&1 && break; sleep 1; done
# Ventana de mantenimiento de ayer: alguien marcó el nodo y no lo desmarcó.
kubectl taint nodes nodo1 mantenimiento=si:NoSchedule

mkdir -p /home/analista/manifiestos
cat > /home/analista/manifiestos/erp.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: reportes, namespace: erp}
spec:
  replicas: 1
  selector: {matchLabels: {app: reportes}}
  template:
    metadata: {labels: {app: reportes}}
    spec:
      containers:
      - name: reportes
        image: busybox:1.36
        command: ["sh", "-c", "echo reportes listo; exec sleep infinity"]
        resources:
          requests: {cpu: "64", memory: 64Mi}   # "64" = 64 núcleos
          limits:   {memory: 128Mi}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: cache, namespace: erp}
spec:
  replicas: 1
  selector: {matchLabels: {app: cache}}
  template:
    metadata: {labels: {app: cache}}
    spec:
      nodeSelector:
        disktype: ssd
      containers:
      - name: cache
        image: busybox:1.36
        command: ["sh", "-c", "echo cache lista; exec sleep infinity"]
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {memory: 64Mi}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: datos-db, namespace: erp}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: rapido-ssd
  resources:
    requests: {storage: 1Gi}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: db, namespace: erp}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers:
      - name: db
        image: busybox:1.36
        command: ["sh", "-c", "date >> /datos/arranques.log; echo db lista; exec sleep infinity"]
        volumeMounts: [{name: datos, mountPath: /datos}]
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {memory: 64Mi}
      volumes:
      - name: datos
        persistentVolumeClaim: {claimName: datos-db}
YML
kubectl apply -f /home/analista/manifiestos/erp.yaml
chown -R analista:analista /home/analista/manifiestos

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pods en Pending (namespace erp)

Ningún pod de erp arranca: todos en Pending. Manifiestos: ~/manifiestos/erp.yaml

1. Lee los eventos del scheduler y anota la causa de cada uno en ~/pending.txt:
     nodo=<qué le pasa al nodo que afecta a todos>
     reportes=<causa>
     cache=<causa>
     db=<causa>
   (palabras clave: taint / cpu / nodeselector / storageclass)
2. Arréglalos:
   - el nodo salió de mantenimiento ayer: quítale la marca.
   - reportes no necesita más de 1 núcleo reservado.
   - cache debe ir a un nodo con disco SSD: el nodo1 lo es (etiquétalo).
   - db: la StorageClass del clúster se llama local-path. Ojo: la
     storageClassName de un PVC no se puede cambiar; hay que recrearlo.
3. Los tres Deployments disponibles y el PVC Bound.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 162 plantado."
