# Jobs y CronJobs

> Kubernetes · Job · CronJob · concurrencyPolicy · backoffLimit · ttlSecondsAfterFinished · timeZone

## Escenario

Las tareas por lotes de la tienda viven en el namespace `lotes` (ficheros en
`~/lotes/`), y ninguna funciona como debe:

```bash
kubectl -n lotes get cronjobs,jobs,pods
```

- **backup** corre cada minuto y tarda 90 s: los backups se apilan.
- **migracion** falla y reintenta decenas de veces.
- **limpieza** debe correr a las 03:00 de Madrid y corre a las 03:00 UTC.
- **informe** lleva semanas sin ejecutarse.

Un `Job` ejecuta pods hasta que terminan bien, con reintentos y límites. Un
`CronJob` crea Jobs según un horario y decide qué hacer si se solapan, si
se pierde una ejecución o cuántos guardar.

## Objetivos

Los requisitos exactos de cada tarea están en `~/TAREA.txt`. En resumen:

1. backup sin solapes, con plazo máximo de ejecución, sin recuperar ejecuciones viejas y con historial limitado.
2. migracion arreglada, completada, con pocos reintentos y borrado automático a la hora.
3. limpieza a las 03:00 de Madrid todo el año.
4. informe ejecutándose otra vez.

## Pistas

```bash
kubectl explain cronjob.spec | less
kubectl -n lotes logs job/migracion
kubectl -n lotes describe cronjob informe
kubectl -n lotes create job prueba --from=cronjob/informe     # ejecución manual
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
