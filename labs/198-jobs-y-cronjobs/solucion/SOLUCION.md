# Solución — Jobs y CronJobs

| Tarea | Problema | Arreglo |
|-------|----------|---------|
| backup | `concurrencyPolicy: Allow` (por defecto) y dura 90 s cada minuto | `Forbid`, `activeDeadlineSeconds: 300` (en jobTemplate), `startingDeadlineSeconds: 60`, historial 3/3 |
| migracion | lee `/config/version` y la clave es `VERSION`; `backoffLimit: 100` | `items: [{key: VERSION, path: version}]`, `backoffLimit: 3`, `ttlSecondsAfterFinished: 3600` |
| limpieza | horario en UTC | `timeZone: Europe/Madrid` |
| informe | `suspend: true` | `suspend: false` |

```yaml
apiVersion: batch/v1
kind: CronJob
metadata: {name: backup, namespace: lotes}
spec:
  schedule: "* * * * *"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 60
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      activeDeadlineSeconds: 300
      template: ...
```

```bash
kubectl -n lotes get jobs -o name | grep '^job.batch/backup-' | xargs -r kubectl -n lotes delete
kubectl -n lotes delete job migracion        # plantilla inmutable
kubectl apply -f ~/lotes/
```

## Detalles

- `concurrencyPolicy: Replace` mata el anterior y arranca el nuevo. Para un backup es peor que saltarse una ejecución.
- `startingDeadlineSeconds` evita que, tras una caída del control plane, se lancen de golpe todas las ejecuciones pendientes.
- Con más de 100 ejecuciones perdidas y sin `startingDeadlineSeconds`, el controlador deja de programar el CronJob.
