# Resolución guiada · Lab 196

:::piensa ¿Qué hace realmente cada identidad?
No partas de "qué permisos tiene", sino de "qué llamadas hace". El CI
aplica manifiestos y espera el rollout, el monitor lista, y la app no llama
a la API. Escribe el rol a partir de esa lista.
:::

## Paso 1 · Quitar el cluster-admin

:::pista Qué pasa
`kubectl apply` no borra lo que quitas de un fichero. Si editas
`despliegue.yaml` y te limitas a aplicarlo, el `ClusterRoleBinding`
`despliegue-admin` sigue vivo: bórralo explícitamente.
:::

## Paso 2 · El Role del CI

:::pista Cómo
Un `Role` en tienda con reglas para `deployments` (`apps`), para
`services` y `configmaps` (grupo `""`) y para `pods` y `pods/log`.
`rollout restart` es un `patch`. `rollout status` además lee
ReplicaSets. Prueba cada verbo con `puede`.
:::

## Paso 3 · Escalar privilegios

:::pista Lo que no debe poder
Quien puede crear RoleBindings puede darse cualquier rol que ya tenga el
clúster. `pods/exec` permite entrar en cualquier contenedor y leer sus
secrets montados. Ninguno de los dos va en el rol.
:::

## Paso 4 · La app

:::pista Cómo
Borra el `Role`/`RoleBinding` `app-todo`. Pon
`automountServiceAccountToken: false` en la ServiceAccount, en el pod o
(mejor) en los dos. Tras el rollout, el directorio del token ya no existe.
:::

## Paso 5 · El monitor

:::pista Cómo
Un `RoleBinding` limita al namespace aunque apunte a un ClusterRole. Hace
falta un `ClusterRole` propio (pods y nodos: get/list/watch) y un
`ClusterRoleBinding`. Ojo: el ClusterRole `view` no incluye secrets, pero sí
mucho más de lo necesario.
:::

## Cómo actuar en una situación así

- Revisa los bindings periódicamente: `kubectl get clusterrolebindings -o json` filtrando `cluster-admin`, o herramientas como rbac-tool y kubectl-who-can.
- Una ServiceAccount por aplicación, nunca `default` con permisos.
- Para el CI, mejor GitOps (Argo CD, lab 167): el pipeline ni siquiera necesita credenciales del clúster.
