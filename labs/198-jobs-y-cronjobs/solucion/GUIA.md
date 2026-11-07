# Resolución guiada · Lab 198

:::piensa Cada campo responde a una pregunta
¿Qué pasa si se solapan? (`concurrencyPolicy`) ¿Y si una ejecución se
cuelga? (`activeDeadlineSeconds`) ¿Y si se pierde una? (`startingDeadlineSeconds`)
¿Cuántas veces reintento? (`backoffLimit`) ¿Cuándo borro lo terminado?
(`ttlSecondsAfterFinished`, `*JobsHistoryLimit`) ¿En qué zona horaria?
(`timeZone`). Por defecto, casi todas las respuestas son las peligrosas.
:::

## Paso 1 · backup

:::pista Campos
Con `concurrencyPolicy: Forbid`, si el anterior sigue, la ejecución se salta.
`activeDeadlineSeconds` va en el **Job** (`jobTemplate.spec`), no en el
CronJob. Después borra los Jobs que ya se solapan.
:::

## Paso 2 · migracion

:::pista Qué pasa
`kubectl logs job/migracion`: "no encuentro /config/version". La ConfigMap
tiene la clave `VERSION`, y un volumen de ConfigMap crea un fichero por
clave con ese mismo nombre. Usa `items: [{key: VERSION, path: version}]`.
La plantilla de un Job es inmutable: bórralo y vuelve a crearlo.
:::

## Paso 3 · limpieza

:::pista Qué pasa
Sin `timeZone`, el horario es UTC. Pasar a "0 1" o "0 2" falla dos veces al
año por el cambio de hora. `timeZone: Europe/Madrid` lo resuelve.
:::

## Paso 4 · informe

:::pista Qué pasa
`kubectl describe cronjob informe` → `Suspend: True`. Alguien lo pausó
"un momento". Prueba con `kubectl create job --from=cronjob/informe`.
:::

## Cómo actuar en una situación así

- Alerta con `kube_cronjob_status_last_successful_time` antiguo: así se detecta un informe que lleva semanas sin ejecutarse.
- Haz las tareas idempotentes: un reintento o un solape no debe corromper nada.
- Usa `restartPolicy: Never` + `backoffLimit` para ver cada intento como un pod distinto, con sus logs.
