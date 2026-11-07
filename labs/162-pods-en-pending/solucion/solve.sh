#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
printf 'nodo=taint\nreportes=cpu\ncache=nodeselector\ndb=storageclass\n' > ~/pending.txt
kubectl taint nodes nodo1 mantenimiento- || true
kubectl label node nodo1 disktype=ssd --overwrite
kubectl -n erp set resources deploy reportes --requests=cpu=250m,memory=64Mi
# La storageClassName es inmutable: se borra el PVC (y el Deployment que lo usa) y se recrea.
kubectl -n erp scale deploy db --replicas=0
kubectl -n erp delete pvc datos-db --wait=true
kubectl apply -f - <<'YML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: datos-db, namespace: erp}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests: {storage: 1Gi}
YML
kubectl -n erp scale deploy db --replicas=1
for d in reportes cache db; do kubectl -n erp rollout status deploy "$d" --timeout=180s; done
kubectl -n erp get pods,pvc
echo "solve.sh completado."
