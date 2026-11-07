#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
L=~/lotes
python3 - <<'PY'
import os
L = os.path.expanduser("~/lotes")
def edita(f, viejo, nuevo):
    p = os.path.join(L, f); s = open(p).read()
    assert viejo in s, (f, viejo)
    open(p, "w").write(s.replace(viejo, nuevo, 1))

# 1. backup: sin solapes, con límites de tiempo e historial.
edita("backup.yaml", '  schedule: "* * * * *"\n', '''  schedule: "* * * * *"
  concurrencyPolicy: Forbid          # si el anterior sigue, ésta se salta
  startingDeadlineSeconds: 60        # no recuperar ejecuciones perdidas viejas
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
''')
edita("backup.yaml", "  jobTemplate:\n    spec:\n", "  jobTemplate:\n    spec:\n      activeDeadlineSeconds: 300     # un backup colgado muere a los 5 min\n")

# 2. migracion: la clave de la ConfigMap se llama VERSION; el script lee
#    /config/version. Se monta la clave con el nombre que espera.
edita("migracion.yaml", "        configMap: {name: migracion}",
      "        configMap:\n          name: migracion\n          items: [{key: VERSION, path: version}]")
edita("migracion.yaml", "  backoffLimit: 100\n", "  backoffLimit: 3\n  ttlSecondsAfterFinished: 3600\n")

# 3. limpieza: la zona horaria la resuelve Kubernetes (incluido el horario de verano).
edita("limpieza.yaml", '  schedule: "0 3 * * *"\n', '  schedule: "0 3 * * *"\n  timeZone: Europe/Madrid\n')

# 4. informe: estaba suspendido.
edita("informe.yaml", "  suspend: true\n", "  suspend: false\n")
PY

# Los Jobs de backup que ya se solapan y la migración vieja (la plantilla de
# un Job es inmutable: hay que recrearlo).
kubectl -n lotes get jobs -o name | grep '^job.batch/backup-' | xargs -r kubectl -n lotes delete
kubectl -n lotes delete job migracion --ignore-not-found --wait=true
kubectl apply -f $L/
kubectl -n lotes wait --for=condition=Complete job/migracion --timeout=120s
kubectl -n lotes logs job/migracion
kubectl -n lotes get cronjobs
echo "solve.sh completado."
