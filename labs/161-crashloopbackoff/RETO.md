# CrashLoopBackOff

> Kubernetes · OOMKilled · livenessProbe · ConfigMap · kubectl describe/logs

## Escenario

Hay un clúster Kubernetes de un nodo (k3s) dentro del lab. En el namespace
`tienda` corren `api`, `worker` y `web`, y los tres están en
**CrashLoopBackOff**: el contenedor arranca, muere, kubelet lo reinicia con
espera creciente (10 s, 20 s, 40 s… hasta 5 min).

CrashLoopBackOff no es una causa: es el síntoma. La causa está en:

- `kubectl describe pod` → `Last State: Terminated`, `Reason` (`OOMKilled`,
  `Error`, `Completed`), `Exit Code` (137 = SIGKILL) y los **Events**
  (`Liveness probe failed`).
- `kubectl logs --previous` → lo que imprimió el contenedor antes de morir.

Manifiestos en `~/manifiestos/tienda.yaml`.

## Objetivos

1. `~/diagnostico.txt` con `api=`, `worker=` y `web=` y la causa de cada uno
   (`oomkilled`, `liveness`, `configmap`).
2. `api`: necesita ~60 MiB al arrancar; súbele el límite de memoria (no le
   quites la carga).
3. `worker`: la livenessProbe debe apuntar al puerto donde escucha la app.
4. `web`: crea el ConfigMap `web-config` con
   `DB_HOST=db.tienda.svc.cluster.local`.
5. Los tres pods Ready y sin reinicios nuevos.

## Pistas

```bash
kubectl -n tienda get pods -w
kubectl -n tienda describe pod -l app=api | sed -n '/Last State/,/Ready/p'
kubectl -n tienda logs deploy/web --previous
kubectl -n tienda get events --sort-by=.lastTimestamp | tail -20
kubectl -n tienda edit deploy worker        # o edita el YAML y kubectl apply -f
kubectl -n tienda create configmap web-config --from-literal=DB_HOST=...
kubectl -n tienda rollout restart deploy web
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
