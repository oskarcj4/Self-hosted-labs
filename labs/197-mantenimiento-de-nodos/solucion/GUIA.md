# Resolución guiada · Lab 197

:::piensa Un PDB es una promesa sobre réplicas
"Siempre al menos N disponibles" sólo deja mover pods si hay **más de N**.
Mira `ALLOWED DISRUPTIONS` en `kubectl get pdb`: si es 0 con todo sano,
ningún drain podrá pasar nunca.
:::

## Paso 1 · pagos

:::pista Qué pasa
2 réplicas con `minAvailable: 2` dan 0 desalojos permitidos. No toques el
PDB, que es el requisito del negocio: sube a 3 réplicas. Drain desaloja
una, espera a que su sustituta esté Ready en nodo1 y sigue con la siguiente.
:::

## Paso 2 · catalogo

:::pista Qué pasa
Es el mismo problema con 1 réplica y `minAvailable: 1`. Con 2 réplicas hay
1 desalojo permitido. Un `topologySpreadConstraint` por
`kubernetes.io/hostname` evita que todas las réplicas acaben en el mismo nodo.
:::

## Paso 3 · informe

:::pista Qué pasa
Es un `Pod` sin controlador. Drain se niega a desalojarlo porque nadie lo
recrearía. Conviértelo en un Deployment (o en un CronJob, si es periódico:
lab 198) y borra el pod suelto.
:::

## Paso 4 · Probar

:::pista Cómo
`mantenimiento nodo2` debe terminar con "nodo2 vacío". En otra terminal,
`watch kubectl get pods -n tienda -o wide` enseña los pods saltando a nodo1
uno a uno.
:::

## Cómo actuar en una situación así

- `ALLOWED DISRUPTIONS` a 0 en estado sano es una alerta: bloqueará los upgrades del clúster (lab 199). Hay que vigilarlo.
- `maxUnavailable: 1` escala mejor que `minAvailable: N` cuando cambian las réplicas (HPA, lab 166).
- `drain --force` y `--disable-eviction` saltan las protecciones. No van en procedimientos automáticos.
