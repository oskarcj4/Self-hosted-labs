#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cat > ~/manifiestos/db.yaml <<'YML'
# Almacén de la tienda: StatefulSet con identidad y volumen propios por réplica.
apiVersion: v1
kind: Service
metadata: {name: db, namespace: tienda}
spec:
  clusterIP: None                 # headless: un registro DNS por pod
  selector: {app: db}
  ports: [{name: http, port: 8080, targetPort: 8080}]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: db, namespace: tienda}
spec:
  serviceName: db                 # db-N.db.tienda.svc.cluster.local
  replicas: 3
  selector: {matchLabels: {app: db}}
  template:
    metadata: {labels: {app: db}}
    spec:
      containers:
      - name: db
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          [ -f /data/id ] || hostname > /data/id
          mkdir -p /tmp/www
          echo "nodo=$(hostname) datos=$(cat /data/id)" > /tmp/www/index.html
          exec httpd -f -p 8080 -h /tmp/www
        ports: [{name: http, containerPort: 8080}]
        readinessProbe:
          httpGet: {path: /, port: 8080}
          periodSeconds: 3
        volumeMounts: [{name: datos, mountPath: /data}]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
  volumeClaimTemplates:           # un PVC por réplica: datos-db-0, datos-db-1...
  - metadata: {name: datos}
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-path
      resources: {requests: {storage: 100Mi}}
YML
# Lo viejo: el Deployment, el PVC compartido y el Service con ClusterIP
# (clusterIP es inmutable: para hacerlo headless hay que recrearlo).
kubectl -n tienda delete deployment db --ignore-not-found
kubectl -n tienda delete service db --ignore-not-found
kubectl -n tienda delete pvc datos-compartidos --ignore-not-found --wait=true
kubectl apply -f ~/manifiestos/db.yaml
kubectl -n tienda rollout status statefulset/db --timeout=300s
probar-db
echo "solve.sh completado."
