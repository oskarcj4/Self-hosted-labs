# Resolución guiada · Lab 195

:::piensa ¿Qué necesita una app con estado?
Identidad (un nombre que no cambie), almacenamiento propio que la siga y,
a menudo, orden al arrancar (db-0 primero). Un Deployment no da nada de
eso. Repasa el manifiesto y mira qué pieza cubre cada necesidad.
:::

## Paso 1 · Service headless

:::pista Qué cambia
Con `clusterIP: None`, el DNS no devuelve una IP virtual: crea un registro
por pod (`db-0.db...`). `clusterIP` es inmutable, así que hay que borrar el
Service y crearlo de nuevo.
:::

## Paso 2 · StatefulSet

:::pista Campos
Usa `kind: StatefulSet` y `serviceName: db` (el headless). El `template` es
el mismo que el del Deployment. El volumen ya no sale del PVC compartido:
`volumeClaimTemplates` con un PVC de nombre `datos`, que se monta igual en `/data`.
:::

## Paso 3 · Limpiar lo viejo

:::pista Orden
Borra el Deployment antes de aplicar: si los dos coexisten, el Service
selecciona pods de ambos. Después borra el PVC `datos-compartidos`, que ya
no usa nadie.
:::

## Paso 4 · Probar la identidad

:::pista Qué probar
`kubectl -n tienda delete pod db-1`, después `probar-db`. Vuelve db-1 y
monta otra vez `datos-db-1`. Si escalas a 1, los PVC de db-1 y db-2 **no**
se borran: al volver a 3, cada pod recupera sus datos.
:::

## Cómo actuar en una situación así

- Una base de datos real en Kubernetes casi siempre va con un operador (CloudNativePG, Strimzi...): gestiona réplicas, failover y backups encima del StatefulSet.
- `persistentVolumeClaimRetentionPolicy` decide si los PVC se borran al escalar hacia abajo o al borrar el StatefulSet.
- Un StatefulSet no hace failover ni replica los datos. Eso es trabajo de la aplicación.
