# Solución — App of Apps

```
~/gitops/
├── raiz.yaml              # la única Application aplicada a mano
├── argocd/                # la raíz despliega este directorio
│   ├── tienda.yaml
│   ├── pagos.yaml         # targetRevision: main (antes: prueba-pagos)
│   └── catalogo.yaml      # nueva
└── apps/{tienda,pagos,catalogo}/
```

`argocd/pagos.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: pagos, namespace: argocd}
spec:
  project: default
  source: {repoURL: http://<ip>:8000/plataforma.git, targetRevision: main, path: apps/pagos}
  destination: {server: https://kubernetes.default.svc, namespace: pagos}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
```

`raiz.yaml`: igual, con `path: argocd` y `destination.namespace: argocd`.

```bash
git add -A && git commit -m "argocd: App of Apps" && git push
kubectl apply -f ~/gitops/raiz.yaml
```

El script completo está en `solve.sh`.

## Qué gana el equipo

| Antes | Después |
|-------|---------|
| Alta de app: `kubectl apply` de alguien con acceso | PR a `argocd/` |
| Rama equivocada, invisible | `targetRevision` en git, visible en la revisión |
| Recuperar Argo CD tras un desastre: reconstruir de memoria | `kubectl apply -f raiz.yaml` |

## Más allá

- ApplicationSet con generador `git directories`: una app por carpeta de `apps/`, sin un fichero por app.
- Varias raíces (plataforma, equipos) con AppProjects que limitan qué namespaces puede tocar cada una.
