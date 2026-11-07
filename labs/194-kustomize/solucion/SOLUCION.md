# Solución — Kustomize

```
~/app/
├── base/
│   ├── kustomization.yaml     resources: [deployment.yaml, service.yaml]
│   ├── deployment.yaml        imagen, probe, volúmenes; memoria 64Mi por defecto
│   └── service.yaml
└── overlays/
    ├── dev/  kustomization.yaml + memoria.yaml (64Mi)
    └── prod/ kustomization.yaml + memoria.yaml (128Mi)
```

`overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources:
- ../../base
labels:
- pairs: {entorno: prod}
  includeSelectors: false     # el selector es inmutable
  includeTemplates: true
replicas:
- {name: web, count: 3}
configMapGenerator:
- name: web-config
  literals:
  - LOG_LEVEL=info
  - index.html=web entorno=prod
patches:
- path: memoria.yaml          # sólo resources.limits.memory: 128Mi
```

```bash
kubectl apply -k ~/app/overlays/dev
kubectl apply -k ~/app/overlays/prod
kubectl -n dev  delete configmap web-config
kubectl -n prod delete configmap web-config
rm -rf ~/app/dev ~/app/prod
```

El script completo está en `solve.sh`.

## Por qué el hash

`web-config-c6cfhdkfbg` cambia de nombre cuando cambia su contenido. El
Deployment pasa a referenciar otro nombre, el pod template cambia y
Kubernetes hace un rollout. Con una ConfigMap fija, los pods seguirían con
la config vieja hasta que alguien los reiniciara.

## Kustomize o Helm

- Kustomize: YAML real, parches y sin lógica. Va bien para tus propias apps con pocos entornos.
- Helm (lab 164): plantillas y valores. Va bien para distribuir software a terceros con muchas opciones.
- Se combinan: `helmCharts:` en Kustomize, o un post-render de Helm.
