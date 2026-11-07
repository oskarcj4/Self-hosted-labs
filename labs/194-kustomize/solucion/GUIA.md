# Resolución guiada · Lab 194

:::piensa Base = lo que nunca cambia entre entornos
Compara las copias (`diff -r ~/app/dev ~/app/prod`). Lo que sale en el diff
va a los overlays y todo lo demás a la base. La readinessProbe que falta en
prod es deriva, no una diferencia buscada: va a la base.
:::

## Paso 1 · La base

:::pista Qué contiene
`deployment.yaml` y `service.yaml` sin `namespace`, y un `kustomization.yaml`
con `resources:`. El Deployment puede seguir referenciando `web-config`:
Kustomize renombra la referencia al nombre con hash que genere el overlay.
:::

## Paso 2 · Los overlays

:::pista Campos útiles
- `namespace: dev`
- `resources: [../../base]`
- `replicas: [{name: web, count: 3}]`
- `configMapGenerator` con `literals` (`LOG_LEVEL=...`, `index.html=...`)
- `patches:` con un parche estratégico que sólo cambia `limits.memory`
:::

## Paso 3 · La etiqueta y el selector

:::pista Trampa
`commonLabels` (o `labels` con `includeSelectors: true`) añade la etiqueta
también al **selector** del Deployment. El selector es inmutable:
`apply` falla con `field is immutable`. Usa `labels` con
`includeSelectors: false` e `includeTemplates: true`. La otra opción es
borrar el Deployment, y eso tiene downtime.
:::

## Paso 4 · Aplicar y limpiar

:::pista Orden
`kubectl apply -k overlays/dev`, después prod. Comprueba con `probar-web`.
Borra la ConfigMap vieja `web-config` (sin hash) y las carpetas `dev/` y `prod/`.
:::

## Cómo actuar en una situación así

- En CI: `kubectl kustomize overlays/<e> | kubeconform` en cada PR, y que el diff entre entornos se lea en la revisión.
- Argo CD y Flux entienden Kustomize de forma nativa: cada Application apunta a un overlay.
- El hash de la ConfigMap es lo que hace que un cambio de config reinicie los pods. Sin él, los pods siguen con la config vieja.
