# Resolución guiada · Lab 162

:::piensa El scheduler siempre dice por qué
Un pod en Pending no ha fallado: nadie lo ha colocado. El evento
`FailedScheduling` lista, nodo por nodo, qué filtro no pasó. Léelo entero: a
menudo hay **dos causas a la vez** (aquí, el taint y la propia del pod).
:::

## Paso 1 · El nodo

:::pista Qué mirar
```bash
kubectl -n erp describe pod -l app=cache | tail -3
kubectl describe node nodo1 | grep -i taint
```
`node(s) had untolerated taint {mantenimiento: si}`. Afecta a todo pod nuevo.
:::

:::pista Cómo arreglarlo
`kubectl taint nodes nodo1 mantenimiento-`
:::

## Paso 2 · reportes

:::pista Qué mirar
`Insufficient cpu`: pide `cpu: "64"` (64 núcleos). El scheduler reserva por
`requests`, no por uso real.
:::

:::pista Cómo arreglarlo
`kubectl -n erp set resources deploy reportes --requests=cpu=250m`
:::

## Paso 3 · cache

:::pista Cómo arreglarlo
`didn't match Pod's node affinity/selector`: pide `disktype=ssd`.
`kubectl label node nodo1 disktype=ssd`
:::

## Paso 4 · db

:::pista Qué mirar
```bash
kubectl -n erp get pvc
kubectl -n erp describe pvc datos-db | tail -3
kubectl get storageclass
```
`storageclass.storage.k8s.io "rapido-ssd" not found`.
:::

:::pista Cómo arreglarlo
`storageClassName` no se puede editar. Escala `db` a 0, borra el PVC, créalo
con `storageClassName: local-path` y vuelve a escalar a 1.
:::

## Cómo actuar en una situación así

- `kubectl describe pod` → sección Events → `FailedScheduling`.
- Pending con PVC: mira primero el PVC (`kubectl get pvc`).
- Al terminar un mantenimiento, `kubectl uncordon` y quita los taints puestos a mano.

## Si te atascas

- El PVC se queda en `Terminating`: hay un pod que lo usa; escala `db` a 0.
- `local-path` es `WaitForFirstConsumer`: el PVC queda Pending hasta que un pod lo usa.
