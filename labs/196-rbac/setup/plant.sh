#!/usr/bin/env bash
# Lab 196: RBAC "para que funcione": el CI es cluster-admin, la app puede leer
# todos los secrets de su namespace y el monitor no ve lo que necesita.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
for ns in tienda pagos observabilidad; do
  kubectl create namespace $ns
  for _ in $(seq 1 60); do kubectl -n $ns get sa default >/dev/null 2>&1 && break; sleep 1; done
done
kubectl -n pagos create secret generic pasarela --from-literal=clave=sk_live_$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
kubectl -n tienda create secret generic db --from-literal=password=$(head -c 9 /dev/urandom | base64)
kubectl -n pagos create deployment pagos --image=busybox:1.36 -- sh -c 'exec sleep infinity'

R=/home/analista/rbac
mkdir -p $R
cat > $R/despliegue.yaml <<'YML'
# Cuenta con la que el CI despliega la tienda.
apiVersion: v1
kind: ServiceAccount
metadata: {name: despliegue, namespace: tienda}
---
# "Daba errores de permisos, así que le puse admin." — alguien, un viernes.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: despliegue-admin}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects:
- {kind: ServiceAccount, name: despliegue, namespace: tienda}
YML
cat > $R/app.yaml <<'YML'
# Permisos de la propia app (usa la ServiceAccount default de tienda).
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: app-todo, namespace: tienda}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: app-todo, namespace: tienda}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: app-todo}
subjects:
- {kind: ServiceAccount, name: default, namespace: tienda}
YML
cat > $R/monitor.yaml <<'YML'
# El monitor de observabilidad tiene que listar pods y nodos de TODO el clúster.
apiVersion: v1
kind: ServiceAccount
metadata: {name: monitor, namespace: observabilidad}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: monitor-view, namespace: observabilidad}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: view}
subjects:
- {kind: ServiceAccount, name: monitor, namespace: observabilidad}
YML
mkdir -p /home/analista/manifiestos
cat > /home/analista/manifiestos/tienda.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: tienda, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: tienda}}
  template:
    metadata: {labels: {app: tienda}}
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 64Mi}}
YML
kubectl apply -f $R/ -f /home/analista/manifiestos/tienda.yaml
kubectl -n tienda rollout status deploy/tienda --timeout=180s
kubectl -n pagos rollout status deploy/pagos --timeout=180s
chown -R analista:analista $R /home/analista/manifiestos

cat > /usr/local/bin/puede <<'SH'
#!/usr/bin/env bash
# puede <cuenta> <verbo> <recurso> [-n ns | -A]
#   cuenta: despliegue | monitor | app      ej.: puede despliegue get secrets -n pagos
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
case "$1" in
  despliegue) as=system:serviceaccount:tienda:despliegue ;;
  monitor)    as=system:serviceaccount:observabilidad:monitor ;;
  app)        as=system:serviceaccount:tienda:default ;;
  *) echo "uso: puede despliegue|monitor|app <verbo> <recurso> [-n ns|-A]"; exit 2 ;;
esac
shift; kubectl auth can-i --as="$as" "$@"
SH
chmod 755 /usr/local/bin/puede

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · RBAC con mínimo privilegio

Tres identidades, y ninguna tiene los permisos correctos (~/rbac/):

1. tienda/despliegue — el CI. Hoy es cluster-admin: puede leer la clave de
   la pasarela de pagos, borrar namespaces o darse más permisos.
   Debe poder SÓLO, en el namespace tienda:
     - get/list/watch/create/update/patch deployments (rollout restart incluido)
     - get/list/watch/create/update/patch services y configmaps
     - get/list/watch pods y ver sus logs (pods/log)
   Y nada de secrets, ni nada fuera de tienda.

2. tienda/default — la cuenta con la que corre la propia app. Tiene "*"
   sobre todo el namespace y la app no habla con la API para nada.
   Quítale todos los permisos y que el pod no monte ningún token
   (automountServiceAccountToken: false). Cambios de la app en
   ~/manifiestos/tienda.yaml.

3. observabilidad/monitor — necesita get/list/watch de pods en TODOS los
   namespaces y de nodos. Hoy sólo ve su propio namespace.
   Sin secrets y sin escribir nada.

Pruébalo:   puede despliegue get secrets -n tienda
            puede monitor list pods -A
            kubectl auth can-i --list --as=system:serviceaccount:tienda:despliegue -n tienda

Guarda todo en ~/rbac/ y ~/manifiestos/ y aplícalo.
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 196 plantado."
