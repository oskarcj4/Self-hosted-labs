# Solución — CrashLoopBackOff

| Pod | Evidencia | Causa | Arreglo |
|-----|-----------|-------|---------|
| api | `Last State: Terminated, Reason: OOMKilled, Exit Code: 137` | límite 32Mi < ~60 MiB de carga | `limits.memory: 128Mi` |
| worker | Evento `Liveness probe failed ... :8081 connection refused` | sonda en puerto equivocado | `livenessProbe.httpGet.port: 8080` |
| web | `logs --previous`: `FATAL: falta la variable DB_HOST` | ConfigMap `web-config` inexistente (ref. `optional: true`) | crear el ConfigMap y reiniciar |

```bash
kubectl -n tienda patch deploy api --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"}]'
kubectl -n tienda patch deploy worker --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/port","value":8080}]'
kubectl -n tienda create configmap web-config --from-literal=DB_HOST=db.tienda.svc.cluster.local
kubectl -n tienda rollout restart deploy web
```

## Por qué

- **OOMKilled**: el límite de memoria es un techo duro del cgroup. Al pasarlo,
  el kernel mata el proceso (SIGKILL, 137). No hay aviso.
- **Liveness mal configurada**: kubelet mata contenedores sanos. Es peor que no
  tener sonda. La liveness sólo debe fallar si el proceso está colgado sin
  remedio; lo que dependa de terceros va en readiness.
- **Config faltante**: `optional: true` oculta el problema hasta el arranque.
  Sin `optional`, el pod se queda en `CreateContainerConfigError`, que se ve
  antes y más claro.

## Más allá del lab

- Fija `requests` según el uso real medido (`kubectl top pod`) y deja margen en
  `limits` para picos de arranque.
- Las sondas se prueban como el código: en staging, con la app de verdad.
