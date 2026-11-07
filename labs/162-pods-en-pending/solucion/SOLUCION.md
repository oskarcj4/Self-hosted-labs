# Solución — Pods en Pending

| Carga | Evento | Causa | Arreglo |
|-------|--------|-------|---------|
| todas | `untolerated taint {mantenimiento: si}` | taint olvidado tras el mantenimiento | `kubectl taint nodes nodo1 mantenimiento-` |
| reportes | `Insufficient cpu` | `requests.cpu: "64"` | `requests.cpu: 250m` |
| cache | `didn't match Pod's node affinity/selector` | `nodeSelector disktype=ssd` sin nodo | `kubectl label node nodo1 disktype=ssd` |
| db | PVC `Pending`: `storageclass "rapido-ssd" not found` | StorageClass inexistente | recrear el PVC con `local-path` |

```bash
kubectl taint nodes nodo1 mantenimiento-
kubectl -n erp set resources deploy reportes --requests=cpu=250m
kubectl label node nodo1 disktype=ssd
kubectl -n erp scale deploy db --replicas=0
kubectl -n erp delete pvc datos-db
# recrear con storageClassName: local-path
kubectl -n erp scale deploy db --replicas=1
```

## Por qué

- El scheduler filtra nodos (recursos, taints, selectores, volúmenes) y puntúa
  los que quedan. Si no queda ninguno, el pod espera en Pending.
- `requests` es una reserva: aunque el nodo esté ocioso, si la suma de
  `requests` no cabe, no entra.
- Los taints repelen; las tolerations permiten (no obligan). Para obligar a ir a
  un nodo se usa `nodeSelector`/afinidad.
- Muchos campos de un PVC son inmutables: se recrea.

## Más allá del lab

- Alertas por pods en Pending > N minutos (`kube_pod_status_phase{phase="Pending"}`).
- Cluster autoscaler: Pending por `Insufficient` es justo lo que lo dispara.
