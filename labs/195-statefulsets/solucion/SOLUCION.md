# Solución — StatefulSets

| Necesidad | Deployment (antes) | StatefulSet (después) |
|-----------|--------------------|-----------------------|
| Nombre | `db-6d9f7c8b5-2xkqp`, aleatorio | `db-0`, `db-1`, `db-2` |
| DNS por pod | no | `db-N.db.tienda.svc.cluster.local` (Service headless) |
| Volumen | un PVC compartido por todos | `datos-db-N`, uno por réplica (`volumeClaimTemplates`) |
| Pod recreado | otro nombre | mismo nombre, mismo PVC |
| Arranque | todos a la vez | en orden: db-0, db-1, db-2 |

```yaml
apiVersion: v1
kind: Service
metadata: {name: db, namespace: tienda}
spec:
  clusterIP: None
  selector: {app: db}
  ports: [{name: http, port: 8080, targetPort: 8080}]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: {name: db, namespace: tienda}
spec:
  serviceName: db
  replicas: 3
  # ...mismo template que el Deployment...
  volumeClaimTemplates:
  - metadata: {name: datos}
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-path
      resources: {requests: {storage: 100Mi}}
```

```bash
kubectl -n tienda delete deployment db
kubectl -n tienda delete service db           # clusterIP es inmutable
kubectl -n tienda delete pvc datos-compartidos
kubectl apply -f ~/manifiestos/db.yaml
```

## Detalles que sorprenden

- Los PVC sobreviven al StatefulSet. `kubectl delete sts db` no borra los datos, salvo que `persistentVolumeClaimRetentionPolicy` diga lo contrario.
- `podManagementPolicy: Parallel` quita el orden de arranque cuando la app no lo necesita.
- Un ReadWriteOnce compartido "funciona" en un nodo único como este y falla en cuanto los pods caen en nodos distintos. Por eso el bug pasaba desapercibido.
