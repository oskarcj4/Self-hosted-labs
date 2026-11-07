# StatefulSets

> Kubernetes · StatefulSet · Service headless · volumeClaimTemplates · identidad estable

## Escenario

El almacén `db` de la tienda es un clúster de tres nodos que se encuentran
por nombre (`db-0`, `db-1`, `db-2`) y guardan cada uno sus propios datos.
Alguien lo desplegó como un **Deployment**:

```bash
probar-db
  db-0.db.tienda.svc.cluster.local   -> sin respuesta
  ...
  pods:
    db-6d9f7c8b5-2xkqp   Running
```

- Los tres pods montan **el mismo** PVC y todos creen ser el mismo nodo.
- Los nombres son aleatorios, así que nadie puede llamar a `db-1`.
- Un pod que muere vuelve con otro nombre.

Un Deployment trata a sus pods como intercambiables. Un **StatefulSet** da
a cada pod un ordinal fijo, un nombre DNS estable (con un Service
*headless*) y su propio volumen, que lo acompaña cuando el pod se recrea.

## Objetivos

1. StatefulSet `db` con 3 réplicas, cada una con su PVC (`local-path`).
2. `db-N.db.tienda.svc.cluster.local:8080` responde `nodo=db-N datos=db-N`.
3. Al borrar un pod, vuelve con el mismo nombre y los mismos datos.
4. No quedan ni el Deployment ni el PVC compartido.
5. Todo en `~/manifiestos/db.yaml` y aplicado.

## Pistas

```bash
kubectl explain statefulset.spec.volumeClaimTemplates
kubectl explain statefulset.spec.serviceName
kubectl -n tienda get pvc
kubectl -n tienda exec deploy/cliente -- nslookup db.tienda.svc.cluster.local
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
