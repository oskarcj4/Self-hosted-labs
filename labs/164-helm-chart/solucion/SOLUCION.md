# Solución — Helm

## 1. Rollback en prod

```bash
helm -n prod history tienda
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         deployed    Upgrade a nginx 1.29 (rc)
helm -n prod rollback tienda 1 --wait
```

La revisión 2 apuntaba a `nginx:1.29-alpine-rc1` (no existe): `ImagePullBackOff`.
El Deployment mantuvo una réplica vieja por la estrategia RollingUpdate, por eso
prod quedó degradado y no caído del todo.

## 2. Chart parametrizado

```yaml
# values.yaml
replicaCount: 2
mensaje: "Bienvenido a la tienda"
image:
  repository: nginx
  tag: "1.27-alpine"
```

```yaml
# templates/deployment.yaml
spec:
  replicas: {{ .Values.replicaCount }}
# templates/configmap.yaml
  index.html: |
    <h1>{{ .Values.mensaje }}</h1>
```

## 3. Ambientes

```bash
# values-staging.yaml
replicaCount: 1
mensaje: "Tienda (staging)"
# values-prod.yaml
replicaCount: 2

helm install tienda ~/charts/tienda -n staging --create-namespace -f ~/charts/tienda/values-staging.yaml
```

## Por qué

- Helm guarda cada revisión como Secret en el namespace de la release: el
  rollback reaplica exactamente lo que había.
- La anotación `checksum/config` fuerza el reinicio de pods cuando cambia el
  ConfigMap (si no, nginx seguiría sirviendo la portada vieja).

## Más allá del lab

- `helm upgrade --atomic --timeout 5m` en el pipeline: rollback automático.
- Versiona el chart (`version:` en Chart.yaml) y publícalo en un registro OCI.
