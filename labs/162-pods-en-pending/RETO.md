# Pods en Pending

> Kubernetes · scheduler · taints · requests · nodeSelector · PVC/StorageClass

## Escenario

En el namespace `erp` hay tres cargas (`reportes`, `cache`, `db`) y **ningún
pod arranca**: todos se quedan en `Pending`. Un pod en Pending es un pod que el
**scheduler no ha podido colocar en ningún nodo**. Siempre explica por qué en
el evento `FailedScheduling`:

```
0/1 nodes are available: 1 Insufficient cpu, 1 node(s) had untolerated taint {...}
```

Las causas típicas:

| Mensaje | Causa |
|---------|-------|
| `Insufficient cpu/memory` | los `requests` no caben en ningún nodo |
| `untolerated taint` | el nodo tiene un taint que el pod no tolera |
| `didn't match Pod's node affinity/selector` | `nodeSelector`/afinidad sin nodo que encaje |
| `unbound immediate PersistentVolumeClaims` / PVC `Pending` | el volumen no se puede aprovisionar |

Manifiestos en `~/manifiestos/erp.yaml`.

## Objetivos

1. `~/pending.txt` con `nodo=`, `reportes=`, `cache=` y `db=` (palabras clave:
   `taint`, `cpu`, `nodeselector`, `storageclass`).
2. Quita el taint `mantenimiento` del nodo (el mantenimiento acabó ayer).
3. `reportes`: reserva como mucho 1 núcleo.
4. `cache`: el nodo1 tiene SSD; etiquétalo `disktype=ssd`.
5. `db`: el PVC `datos-db` debe usar la StorageClass `local-path` (recréalo) y
   quedar `Bound`.
6. Los tres Deployments disponibles.

## Pistas

```bash
kubectl -n erp get pods,pvc
kubectl -n erp describe pod -l app=reportes | tail -5
kubectl describe node nodo1 | grep -iA3 taints
kubectl get storageclass
kubectl taint nodes nodo1 mantenimiento-          # el '-' final lo quita
kubectl label node nodo1 disktype=ssd
kubectl -n erp delete pvc datos-db                # se queda en Terminating mientras un pod lo use
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
