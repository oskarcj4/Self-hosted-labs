# App of Apps

> GitOps · Argo CD · patrón App of Apps · Applications declarativas · prune y selfHeal

## Escenario

Argo CD despliega desde git, pero las **Applications** de Argo CD se
crearon a mano con `kubectl` y no están en ningún repo. Es GitOps a medias:

```bash
kubectl -n argocd get applications
```

- `tienda` funciona.
- `pagos` sigue una rama de una prueba antigua y sirve la versión vieja. Nadie lo sabía, porque no estaba escrito en ningún sitio.
- `catalogo` lleva semanas en el repo y nadie la dio de alta.

El patrón **App of Apps**: una Application raíz despliega un directorio de
git que contiene *otras Applications*. A partir de ahí, dar de alta, de
baja o cambiar una aplicación es un commit, revisable y auditable como
todo lo demás.

## Objetivos

1. Las Applications de `tienda`, `pagos` y `catalogo` en `~/gitops/argocd/`, desde `main`, con `automated` (prune + selfHeal).
2. Una Application `raiz` que despliega ese directorio, guardada en `~/gitops/raiz.yaml` y aplicada una vez a mano.
3. Las tres apps Synced/Healthy y `pagos` en v2.
4. Dar de alta y de baja una app es sólo un commit (el check lo prueba).

## Pistas

```bash
kubectl -n argocd get app pagos -o yaml          # spec.source.targetRevision
argocd app list --core                           # CLI en modo core
kubectl -n argocd annotate app raiz argocd.argoproj.io/refresh=hard --overwrite
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh      # incluye un alta y una baja reales (1-3 min)
```
