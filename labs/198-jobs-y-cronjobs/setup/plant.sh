#!/usr/bin/env bash
# Lab 198: tareas por lotes mal configuradas: backups que se solapan, una
# migración que reintenta sin fin, una limpieza a la hora equivocada y un
# informe que lleva semanas sin ejecutarse.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl create namespace lotes
for _ in $(seq 1 60); do kubectl -n lotes get sa default >/dev/null 2>&1 && break; sleep 1; done

M=/home/analista/lotes
mkdir -p $M
cat > $M/backup.yaml <<'YML'
# Backup de la base de datos cada minuto. Cada backup tarda ~90 s.
apiVersion: batch/v1
kind: CronJob
metadata: {name: backup, namespace: lotes}
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox:1.36
            command: ["sh", "-c", "echo inicio $(date); sleep 90; echo backup ok"]
            resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
cat > $M/migracion.yaml <<'YML'
# Migración de esquema que se lanza una vez por despliegue.
apiVersion: v1
kind: ConfigMap
metadata: {name: migracion, namespace: lotes}
data:
  VERSION: "42"
---
apiVersion: batch/v1
kind: Job
metadata: {name: migracion, namespace: lotes}
spec:
  backoffLimit: 100
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrar
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          v=$(cat /config/version 2>/dev/null) || { echo "ERROR: no encuentro /config/version"; exit 1; }
          echo "migrando el esquema a la versión $v"; sleep 2; echo "migración $v completada"
        volumeMounts: [{name: config, mountPath: /config}]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
      volumes:
      - name: config
        configMap: {name: migracion}
YML
cat > $M/limpieza.yaml <<'YML'
# Limpieza de carritos abandonados: a las 03:00, hora de Madrid, cuando no
# hay tráfico.
apiVersion: batch/v1
kind: CronJob
metadata: {name: limpieza, namespace: lotes}
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: limpiar
            image: busybox:1.36
            command: ["sh", "-c", "echo limpiando carritos; sleep 5"]
            resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
cat > $M/informe.yaml <<'YML'
# Informe de ventas cada hora. "Lleva semanas sin llegar al correo."
apiVersion: batch/v1
kind: CronJob
metadata: {name: informe, namespace: lotes}
spec:
  schedule: "0 * * * *"
  suspend: true
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: informe
            image: busybox:1.36
            command: ["sh", "-c", "echo informe de ventas enviado"]
            resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
kubectl apply -f $M/
chown -R analista:analista $M
# Deja que se vea el problema: unos minutos de backups solapándose y
# reintentos de la migración.
sleep 150

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Jobs y CronJobs (namespace lotes, ficheros en ~/lotes/)

  kubectl -n lotes get cronjobs,jobs,pods

1. backup: cada minuto, pero cada backup tarda ~90 s y se van apilando
   (dos backups a la vez sobre la misma base de datos).
   - Nunca dos a la vez: si toca y el anterior sigue, se salta.
   - Un backup colgado se mata a los 5 minutos como mucho (y tiene que
     dar tiempo a uno normal de 90 s).
   - Si el planificador se pierde una ejecución, no la recupera pasado
     1 minuto (startingDeadlineSeconds ≤ 60).
   - Guarda como mucho 3 Jobs terminados bien y 3 fallidos.

2. migracion: falla y lleva decenas de reintentos.
   - Arregla la causa: tiene que completarse.
   - Como mucho 3 reintentos (no 100).
   - El Job terminado se borra solo al cabo de 1 hora (ttlSecondsAfterFinished),
     no antes: hay que poder leer sus logs.

3. limpieza: tiene que correr a las 03:00 hora de Madrid, y hoy corre a las
   03:00 UTC (las 04:00 o 05:00 en Madrid). Arréglalo sin hacer cuentas
   de horario de verano.

4. informe: lleva semanas sin ejecutarse. Averigua por qué y arréglalo.

Guarda los cambios en ~/lotes/ y aplícalos.
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 198 plantado."
