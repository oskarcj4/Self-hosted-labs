# Resolución guiada · Lab 200

:::piensa ¿Qué no está en git?
`kubectl -n argocd get app -o yaml` enseña lo que hay. Todo lo que ves ahí
y no está en el repo es configuración que nadie revisa. Así se coló la rama
`prueba-pagos`.
:::

## Paso 1 · Las Applications hijas, en git

:::pista Cómo
Exporta cada una (`kubectl -n argocd get app tienda -o yaml`) y quédate con
`metadata.name`, `metadata.namespace: argocd` y `spec`, sin `status`. Pon
`targetRevision: main` en todas, añade
`syncPolicy.automated: {prune: true, selfHeal: true}` y crea la de
catalogo. Haz commit y push.
:::

## Paso 2 · La raíz

:::pista Cómo
Una Application más con `path: argocd`, `destination.namespace: argocd` y
automated. Guárdala en `raiz.yaml` (fuera de `argocd/`, para que no se
gestione a sí misma) y haz `kubectl apply -f raiz.yaml`. La raíz adopta las
Applications que ya existían con el mismo nombre.
:::

## Paso 3 · Comprobar

:::pista Qué mirar
`kubectl -n argocd get app` → todas Synced/Healthy. `kubectl -n pagos get deploy`
→ 2 réplicas. Prueba a añadir un fichero en `argocd/`, hacer push y refrescar la raíz.
:::

## Cómo actuar en una situación así

- `prune` en la raíz significa que borrar el fichero borra la Application. Añade el finalizer `resources-finalizer.argocd.argoproj.io` a las hijas solo si quieres que eso borre también sus recursos.
- Con muchas apps parecidas, un **ApplicationSet** (generador de directorios de git o de clústeres) evita copiar YAML.
- Protege `argocd/` con CODEOWNERS: quien la toca decide qué corre en producción.
