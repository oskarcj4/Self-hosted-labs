# Resolución guiada · Lab 161

:::piensa CrashLoopBackOff es el síntoma
Kubernetes sólo te dice "lo reinicio y vuelve a morir". La causa está en el
**estado anterior** del contenedor (`Last State`), en los **eventos** y en los
**logs del intento previo**. Mira las tres fuentes antes de tocar nada.
:::

## Paso 1 · api

:::pista Qué mirar
```bash
kubectl -n tienda describe pod -l app=api | grep -A5 'Last State'
```
`Reason: OOMKilled`, `Exit Code: 137`: el kernel lo mató por pasar el límite
de memoria del cgroup (32Mi). La carga inicial necesita ~60 MiB.
:::

:::pista Cómo arreglarlo
Sube `resources.limits.memory` (p. ej. `128Mi`) y ajusta `requests` a lo que
usa de verdad: `kubectl -n tienda edit deploy api`.
:::

## Paso 2 · worker

:::pista Qué mirar
```bash
kubectl -n tienda get events --field-selector involvedObject.kind=Pod | grep -i liveness
```
`Liveness probe failed: ... connect: connection refused` en el puerto 8081.
La app escucha en 8080: el contenedor está sano, la sonda está mal.
:::

## Paso 3 · web

:::pista Qué mirar
```bash
kubectl -n tienda logs deploy/web --previous
```
`FATAL: falta la variable DB_HOST`. El `configMapKeyRef` es `optional: true`,
así que el pod arranca aunque el ConfigMap no exista… y la app muere.
:::

:::pista Cómo arreglarlo
```bash
kubectl -n tienda create configmap web-config --from-literal=DB_HOST=db.tienda.svc.cluster.local
kubectl -n tienda rollout restart deploy web
```
:::

## Cómo actuar en una situación así

- `describe` → `logs --previous` → `events`. Siempre en ese orden.
- Exit 137 + OOMKilled = memoria. Exit 1 = la app decidió salir (lee sus logs).
- Reinicios sin logs de error y con eventos de probe = la sonda, no la app.

## Si te atascas

- El check dice que api no está Ready: el límite debe dejar margen (>= 80Mi).
- web sigue fallando tras crear el ConfigMap: reinicia el Deployment.
