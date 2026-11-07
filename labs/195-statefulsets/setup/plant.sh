#!/usr/bin/env bash
# Lab 195: un almacén "con estado" desplegado como Deployment: tres réplicas
# que comparten un único volumen, nombres aleatorios y un Service normal.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl -n kube-system rollout status deploy/local-path-provisioner --timeout=300s
kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done

M=/home/analista/manifiestos
mkdir -p $M
cat > $M/db.yaml <<'YML'
# Almacén de la tienda. Cada nodo guarda en /data su identidad y sus datos,
# y los demás lo encuentran por nombre (db-0, db-1, db-2).
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: datos-compartidos, namespace: tienda}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources: {requests: {storage: 100Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: db, namespace: tienda}
spec:
  selector: {app: db}
  ports: [{name: http, port: 8080, targetPort: 8080}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: db, namespace: tienda}
spec:
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
      volumes:
      - name: datos
        persistentVolumeClaim: {claimName: datos-compartidos}
YML
cat > $M/cliente.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: cliente, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: cliente}}
  template:
    metadata: {labels: {app: cliente}}
    spec:
      containers:
      - name: cliente
        image: busybox:1.36
        command: ["sh", "-c", "exec sleep infinity"]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
kubectl apply -f $M/
kubectl -n tienda rollout status deploy/db --timeout=180s
kubectl -n tienda rollout status deploy/cliente --timeout=180s
chown -R analista:analista $M

cat > /usr/local/bin/probar-db <<'SH'
#!/usr/bin/env bash
# probar-db — pide cada nodo por su nombre estable, desde el pod cliente.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for i in 0 1 2; do
  h=db-$i.db.tienda.svc.cluster.local
  r=$(kubectl -n tienda exec deploy/cliente -- wget -q -T 3 -O - "http://$h:8080/" 2>/dev/null)
  printf '  %-36s -> %s\n' "$h" "${r:-sin respuesta}"
done
echo "  pods:"
kubectl -n tienda get pods -l app=db --no-headers -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase | sed 's/^/    /'
SH
chmod 755 /usr/local/bin/probar-db

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · StatefulSets (namespace tienda)

El almacén "db" está desplegado como un Deployment (~/manifiestos/db.yaml):

  - los tres pods comparten UN volumen: todos creen ser el mismo nodo;
  - se llaman db-7f9c8-xk2lp: nadie puede encontrar a "db-1";
  - si un pod muere, vuelve con otro nombre.

  probar-db

Conviértelo en un StatefulSet:
  1. Tres réplicas: db-0, db-1, db-2, cada una con SU volumen (local-path).
  2. Cada una accesible por nombre estable:
       db-N.db.tienda.svc.cluster.local:8080 -> "nodo=db-N datos=db-N"
     (Service headless "db").
  3. Si borras un pod, vuelve con el mismo nombre y los mismos datos.
  4. Sin restos: ni el Deployment ni el PVC compartido.
  5. Todo en ~/manifiestos/db.yaml y aplicado.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 195 plantado."
