# Resolución guiada · Lab 164

:::piensa Primero apaga el fuego
prod está degradado: arregla eso antes de refactorizar el chart. Con Helm,
volver atrás es un comando porque cada revisión guarda los manifiestos completos.
:::

## Paso 1 · Rollback en prod

:::pista Qué mirar
```bash
helm -n prod history tienda
kubectl -n prod get pods          # ImagePullBackOff en los nuevos
```
La revisión 2 cambió `image.tag` a `1.29-alpine-rc1`, que no existe.
:::

:::pista Cómo hacerlo
`helm -n prod rollback tienda 1 --wait`. Crea la revisión 3 ("Rollback to 1").
:::

## Paso 2 · Parametrizar

:::pista Cómo hacerlo
- `templates/deployment.yaml`: `replicas: {{ .Values.replicaCount }}`
- `templates/configmap.yaml`: `<h1>{{ .Values.mensaje }}</h1>`
- `values.yaml`: `replicaCount: 2` y `mensaje: "Bienvenido a la tienda"`
:::

## Paso 3 · Valores por ambiente y staging

:::pista Cómo hacerlo
```bash
printf 'replicaCount: 1\nmensaje: "Tienda (staging)"\n' > ~/charts/tienda/values-staging.yaml
printf 'replicaCount: 2\n' > ~/charts/tienda/values-prod.yaml
helm install tienda ~/charts/tienda -n staging --create-namespace -f ~/charts/tienda/values-staging.yaml
```
:::

## Cómo actuar en una situación así

- `helm upgrade --atomic --wait`: si no queda sano, revierte solo.
- `helm diff upgrade` (plugin) antes de tocar prod.
- Un único chart; lo que cambia por ambiente vive en `values-<amb>.yaml`.

## Si te atascas

- `helm lint` falla con "nil pointer": falta el valor en `values.yaml`.
- El check de prod falla tras el rollback: espera a que terminen los pods (`--wait`).
