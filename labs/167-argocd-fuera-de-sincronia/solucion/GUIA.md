# Resolución guiada · Lab 167

:::piensa Antes de sincronizar, decide
Sincronizar sin mirar borra **todo** lo que no esté en git, incluido el cambio
bueno. Primero el diff; luego llevas a git lo que se queda; y sólo entonces sync.
:::

## Paso 1 · ¿Qué tiene drift?

:::pista Qué mirar
```bash
argocd --core app diff tienda
kubectl -n argocd get app tienda -o jsonpath='{range .status.resources[*]}{.kind}/{.name}: {.status}{"\n"}{end}'
```
`Deployment/tienda` (replicas 5, env MODO_DEBUG) y `ConfigMap/tienda-web` (mensaje).
:::

## Paso 2 · El cambio bueno, a git

:::pista Cómo hacerlo
Edita `~/gitops/apps/tienda/tienda.yaml`, añade `<p>Envío gratis hoy</p>` al
`index.html`, `git commit` y `git push`.
:::

## Paso 3 · Sync y auto-sync

:::pista Cómo hacerlo
```bash
kubectl -n argocd patch app tienda --type merge -p \
 '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true},"syncOptions":["CreateNamespace=true"]}}}'
kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=hard --overwrite
```
Con `automated`, Argo CD sincroniza solo al ver el commit; `selfHeal` revierte
los cambios a mano; `prune` borra lo que ya no está en git.
:::

## Cómo actuar en una situación así

- En guardia, si hay que tocar a mano, **apúntalo** y llévalo a git después
  (o pausa el auto-sync de esa app conscientemente).
- `selfHeal` convierte el "kubectl edit" de emergencia en algo que no dura:
  bueno para la disciplina, malo si nadie lo sabe. Comunícalo.

## Si te atascas

- Sigue OutOfSync tras el push: Argo CD lee git cada ~3 min; fuerza con `refresh=hard`.
- `argocd --core` se queja del namespace: tu `~/.kube/config` ya usa `argocd`.
