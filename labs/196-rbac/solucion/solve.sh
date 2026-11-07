#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
R=~/rbac

cat > $R/despliegue.yaml <<'YML'
# Cuenta con la que el CI despliega la tienda: sólo lo necesario, sólo en tienda.
apiVersion: v1
kind: ServiceAccount
metadata: {name: despliegue, namespace: tienda}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: despliegue, namespace: tienda}
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["replicasets"]          # rollout status los consulta
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: despliegue, namespace: tienda}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: despliegue}
subjects:
- {kind: ServiceAccount, name: despliegue, namespace: tienda}
YML

cat > $R/app.yaml <<'YML'
# La app no habla con la API: su cuenta no tiene permisos ni monta token.
apiVersion: v1
kind: ServiceAccount
metadata: {name: default, namespace: tienda}
automountServiceAccountToken: false
YML

cat > $R/monitor.yaml <<'YML'
# El monitor lee pods de todo el clúster y nodos. Nada más.
apiVersion: v1
kind: ServiceAccount
metadata: {name: monitor, namespace: observabilidad}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: monitor-lectura}
rules:
- apiGroups: [""]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: monitor-lectura}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: monitor-lectura}
subjects:
- {kind: ServiceAccount, name: monitor, namespace: observabilidad}
YML

# El pod tampoco monta token, aunque alguien vuelva a activarlo en la SA.
python3 - <<'PY'
import os
p = os.path.expanduser("~/manifiestos/tienda.yaml")
s = open(p).read()
if "automountServiceAccountToken" not in s:
    s = s.replace("    spec:\n      containers:", "    spec:\n      automountServiceAccountToken: false\n      containers:")
open(p, "w").write(s)
PY

# Lo viejo fuera: kubectl apply no borra lo que ya no está en los ficheros.
kubectl delete clusterrolebinding despliegue-admin --ignore-not-found
kubectl -n tienda delete rolebinding app-todo --ignore-not-found
kubectl -n tienda delete role app-todo --ignore-not-found
kubectl -n observabilidad delete rolebinding monitor-view --ignore-not-found
kubectl apply -f $R/ -f ~/manifiestos/tienda.yaml
kubectl -n tienda rollout status deploy/tienda --timeout=120s

puede despliegue get secrets -n tienda || true
puede despliegue patch deployments -n tienda
puede monitor list pods -A
puede app list pods -n tienda || true
echo "solve.sh completado."
