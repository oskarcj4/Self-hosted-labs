#!/usr/bin/env bash
# Lab 197: hay que vaciar nodo2 para mantenimiento y "kubectl drain" no termina
# nunca: un PDB imposible, un Deployment de una réplica con PDB y un pod suelto.
set -e
# En el contenedor del segundo nodo no hay nada que plantar.
[ "$(hostname)" = k8s-197-nodo2 ] && exit 0
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for n in nodo1 nodo2; do
  for _ in $(seq 1 300); do kubectl get node $n 2>/dev/null | grep -qw Ready && break; sleep 2; done
  kubectl wait --for=condition=Ready node/$n --timeout=300s
done
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done

M=/home/analista/manifiestos
mkdir -p $M
web(){ echo "mkdir -p /www && echo '$1 ok' > /www/index.html && exec httpd -f -p 8080 -h /www"; }
cat > $M/pagos.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: pagos, namespace: tienda}
spec:
  replicas: 2
  selector: {matchLabels: {app: pagos}}
  template:
    metadata: {labels: {app: pagos}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web pagos)"]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 2}
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
# Pagos nunca puede bajar de 2 pods disponibles.
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: pagos, namespace: tienda}
spec:
  minAvailable: 2
  selector: {matchLabels: {app: pagos}}
YML
cat > $M/catalogo.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalogo, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: catalogo}}
  template:
    metadata: {labels: {app: catalogo}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web catalogo)"]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 2}
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
# El catálogo siempre tiene que tener al menos un pod sirviendo.
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: catalogo, namespace: tienda}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: catalogo}}
YML
cat > $M/informe.yaml <<'YML'
# Genera el informe de ventas cada minuto. Tiene que seguir funcionando
# después del mantenimiento.
apiVersion: v1
kind: Pod
metadata:
  name: informe
  namespace: tienda
  labels: {app: informe}
spec:
  containers:
  - name: informe
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo \"$(date) informe generado\"; sleep 60; done"]
    resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
# Todo arranca en nodo2: nodo1 acordonado mientras se crea.
kubectl cordon nodo1
kubectl apply -f $M/
kubectl -n tienda rollout status deploy/pagos --timeout=180s
kubectl -n tienda rollout status deploy/catalogo --timeout=180s
kubectl -n tienda wait --for=condition=Ready pod/informe --timeout=180s
kubectl uncordon nodo1
chown -R analista:analista $M

cat > /usr/local/bin/mantenimiento <<'SH'
#!/usr/bin/env bash
# mantenimiento <nodo> — lo que hace el equipo de plataforma antes de parchear
# un nodo: vaciarlo SIN forzar nada. Si no termina en 2 minutos, se aborta.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
N=${1:-nodo2}
echo "== Vaciando $N (kubectl drain, sin --force) =="
if kubectl drain "$N" --ignore-daemonsets --timeout=120s; then
  echo "== $N vacío: aquí se parchearía y reiniciaría el nodo =="
  sleep 3
else
  echo "== drain NO ha terminado: el mantenimiento se aborta =="
fi
kubectl uncordon "$N" >/dev/null && echo "== $N vuelve a aceptar pods =="
SH
chmod 755 /usr/local/bin/mantenimiento

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Mantenimiento de nodos (drain y PodDisruptionBudgets)

El clúster tiene dos nodos. Hay que parchear nodo2, y el procedimiento
estándar es vaciarlo primero:

  mantenimiento nodo2          # kubectl drain nodo2 --ignore-daemonsets (sin --force)

No termina nunca. Arregla las cargas (~/manifiestos/), no el procedimiento:

  - pagos: nunca puede bajar de 2 pods disponibles, tampoco durante el drain;
  - catalogo: siempre al menos 1 pod sirviendo;
  - informe: tiene que seguir corriendo después del mantenimiento (y hoy
    drain se niega a tocarlo; con --force desaparecería para siempre).

No vale borrar los PodDisruptionBudgets ni relajarlos por debajo de lo
anterior. Al acabar, "mantenimiento nodo2" debe vaciar el nodo sin cortes.

  kubectl get pdb -n tienda          # fíjate en ALLOWED DISRUPTIONS
  kubectl get pods -n tienda -o wide

Comprueba:  bash /opt/lab/check.sh    (hace un drain real de nodo2, ~1-2 min)
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 197 plantado."
