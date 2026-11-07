# Solución — Argo CD fuera de sincronía

## Drift

| Recurso | Live (clúster) | Git | Decisión |
|---------|---------------|-----|----------|
| deployment/tienda | `replicas: 5`, env `MODO_DEBUG=1` | `replicas: 2`, sin env | revertir |
| configmap/tienda-web | "…Envío gratis hoy" | sin el párrafo | llevar a git |

## Pasos

```bash
# 1. el cambio bueno, a git
cd ~/gitops && vi apps/tienda/tienda.yaml      # + <p>Envío gratis hoy</p>
git commit -am "tienda: Envío gratis hoy" && git push

# 2. auto-sync con self-heal y prune
kubectl -n argocd patch app tienda --type merge -p \
 '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true},"syncOptions":["CreateNamespace=true"]}}}'
kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=hard --overwrite
```

Resultado: Synced/Healthy, 2 réplicas, sin `MODO_DEBUG`, mensaje nuevo.

## Por qué

- **Drift** = diferencia entre lo vivo y lo declarado. Sin self-heal, Argo CD
  sólo lo *señala* (OutOfSync); con self-heal lo *corrige*.
- **prune** es lo que hace que borrar un fichero en git borre el recurso; sin
  él quedan huérfanos.
- Llevar el hotfix a git primero evita que el sync lo destruya.

## Más allá del lab

- Notificaciones de Argo CD (Slack) en `OutOfSync` y `SyncFailed`.
- `ignoreDifferences` para campos que gestiona otro controlador (p. ej. réplicas con HPA).
- Ventanas de sincronización (`syncWindows`) para congelar cambios en fechas críticas.
