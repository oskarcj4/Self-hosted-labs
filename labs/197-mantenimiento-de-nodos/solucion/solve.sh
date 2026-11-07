#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
M=~/manifiestos
# 1. pagos: con 2 réplicas y minAvailable 2 nunca se puede desalojar ninguna.
#    Una réplica de margen: 3 réplicas, el PDB sigue exigiendo 2.
sed -i 's/^  replicas: 2$/  replicas: 3/' $M/pagos.yaml
# 2. catalogo: una sola réplica con minAvailable 1 tampoco se puede mover.
sed -i 's/^  replicas: 1$/  replicas: 2/' $M/catalogo.yaml
# Y que las réplicas no caigan todas en el mismo nodo.
python3 - <<'PY'
import os
for app in ("pagos", "catalogo"):
    p = os.path.expanduser(f"~/manifiestos/{app}.yaml")
    s = open(p).read()
    if "topologySpreadConstraints" not in s:
        s = s.replace("    spec:\n      containers:", f"""    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector: {{matchLabels: {{app: {app}}}}}
      containers:""", 1)
    open(p, "w").write(s)
PY
# 3. informe: un pod suelto no lo recrea nadie. Pasa a Deployment.
cat > $M/informe.yaml <<'YML'
# Genera el informe de ventas cada minuto. Un Deployment lo recrea en otro
# nodo cuando drain lo desaloja.
apiVersion: apps/v1
kind: Deployment
metadata: {name: informe, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: informe}}
  template:
    metadata: {labels: {app: informe}}
    spec:
      containers:
      - name: informe
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo \"$(date) informe generado\"; sleep 60; done"]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
kubectl apply -f $M/
kubectl -n tienda rollout status deploy/informe --timeout=120s
kubectl -n tienda delete pod informe --ignore-not-found
kubectl -n tienda rollout status deploy/pagos --timeout=120s
kubectl -n tienda rollout status deploy/catalogo --timeout=120s
kubectl -n tienda get pdb
mantenimiento nodo2
echo "solve.sh completado."
