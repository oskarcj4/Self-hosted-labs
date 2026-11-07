# Helm

> Kubernetes · Helm · chart propio · valores por ambiente · upgrade · rollback

## Escenario

La tienda se despliega con un chart propio en `~/charts/tienda`. Anoche alguien
hizo `helm upgrade` en **prod** con una imagen que no existe: los pods nuevos
están en `ImagePullBackOff` y sólo queda viva una réplica vieja.

Además el chart tiene valores fijos en las plantillas (`replicas: 2`, el texto
de la portada), así que no sirve para **staging**, que necesita 1 réplica y su
propio mensaje.

Conceptos:

- **Release**: una instalación de un chart en un namespace. Cada `install`,
  `upgrade` o `rollback` crea una **revisión** (`helm history`).
- **values**: `values.yaml` da los valores por defecto; `-f values-<amb>.yaml`
  o `--set` los sobrescriben. Las plantillas los leen con `{{ .Values.x }}`.

## Objetivos

1. **prod**: `helm rollback` a la última revisión buena. Pods Ready con la
   imagen `nginx:1.27-alpine`.
2. Parametriza el chart: `replicaCount` → `spec.replicas` (por defecto 2) y
   `mensaje` → texto del `index.html` (por defecto `Bienvenido a la tienda`).
   `helm lint` sin errores.
3. `values-staging.yaml` (`replicaCount: 1`, `mensaje` con la palabra
   `staging`) y `values-prod.yaml` (`replicaCount: 2`) dentro del chart.
4. Release `tienda` en el namespace `staging` instalada con
   `values-staging.yaml`.

## Pistas

```bash
helm list -A
helm -n prod history tienda
helm -n prod rollback tienda <REVISION>
kubectl -n prod get pods
helm lint ~/charts/tienda
helm template t ~/charts/tienda --set replicaCount=4 | grep replicas
helm install tienda ~/charts/tienda -n staging --create-namespace -f ~/charts/tienda/values-staging.yaml
helm -n staging get values tienda
```

Sintaxis de plantilla: `replicas: {{ .Values.replicaCount }}` y, dentro de un
bloque, `{{ .Values.mensaje }}`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
