# Argo CD fuera de sincronía

> GitOps · Argo CD · drift · app diff · sync · selfHeal · prune

## Escenario

Argo CD despliega la app `tienda` desde un repo git (tu copia: `~/gitops`,
ruta `apps/tienda`). En GitOps **git es la verdad**: el clúster debe ser
exactamente lo que dice el repo.

Anoche, durante una guardia, alguien tocó el clúster a mano y la app quedó
**OutOfSync**. El ticket de la guardia dice:

| Cambio a mano | Decisión |
|---------------|----------|
| "escalé a 5 para aguantar" | ya no hace falta: vuelve a lo de git |
| "activé `MODO_DEBUG` para investigar" | olvidado: fuera |
| "cambié el mensaje: *Envío gratis hoy*" | lo pidió negocio: **se queda** |

Los cambios buenos se llevan a git; los malos se revierten sincronizando.

## Objetivos

1. `~/drift.txt` con los recursos con drift, uno por línea (`kind/nombre`).
2. El mensaje "Envío gratis hoy" en git (commit + push en `~/gitops`).
3. App `tienda` **Synced** y **Healthy**: 2 réplicas, sin `MODO_DEBUG`, con el
   mensaje nuevo.
4. `syncPolicy.automated` con `selfHeal: true` y `prune: true`. El check
   escalará el Deployment a mano y esperará que Argo CD lo revierta.

## Pistas

```bash
argocd --core app list                      # CLI en modo core (sin servidor)
argocd --core app get tienda
argocd --core app diff tienda               # live vs git
argocd --core app sync tienda
kubectl -n argocd get app tienda -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl -n argocd get app tienda -o jsonpath='{range .status.resources[*]}{.kind}/{.name}: {.status}{"\n"}{end}'
kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=hard --overwrite   # releer git ya
kubectl -n argocd edit app tienda           # spec.syncPolicy.automated
cd ~/gitops && git add -A && git commit -m "..." && git push
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
