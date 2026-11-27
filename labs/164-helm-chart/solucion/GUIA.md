# Resolución guiada · Lab 164

:::piensa Primero apaga el fuego
prod está degradado: arregla eso antes de tocar el chart. Con Helm, volver
atrás es un comando, porque cada instalación o actualización (`install`,
`upgrade`, `rollback`) crea una **revisión** que guarda los manifiestos
completos. Después, el chart: un chart sirve para varios ambientes sólo si lo
que cambia entre ellos son **valores**, no plantillas.
:::

**El plan:** (1) volver atrás en prod, (2) parametrizar el chart,
(3) valores por ambiente y (4) instalar staging.

## Paso 1 · Rollback en prod

:::pista Cómo hacerlo
```bash
helm list -A
helm -n prod history tienda
kubectl -n prod get pods
```
- `helm list -A` lista las instalaciones (*releases*) de todos los namespaces.
- `history` lista sus revisiones, con estado y descripción.

**Qué deberías ver:** la revisión 2 en `deployed`, con pods nuevos en
`ImagePullBackOff` (Kubernetes no puede descargar la imagen: el tag
`1.29-alpine-rc1` no existe), y la 1 como `superseded`. Vuelve a la 1:
```bash
helm -n prod rollback tienda 1 --wait
helm -n prod history tienda
kubectl -n prod get pods
```
`--wait` no termina hasta que los pods están listos. El rollback no borra la
revisión 2: crea una nueva, la 3, con los manifiestos de la 1.

**Qué deberías ver:** revisión 3 "Rollback to 1" y los pods `Running`.
:::

## Paso 2 · Parametriza el chart

**Pregúntate:** ¿qué cambia entre staging y prod? Eso son valores.

:::pista Cómo hacerlo
```bash
cd ~/charts/tienda
grep -n 'replicas\|Bienvenido' templates/*.yaml
```
En las plantillas, sustituye los valores fijos por referencias:
- `templates/deployment.yaml`: `replicas: {{ .Values.replicaCount }}`
- `templates/configmap.yaml`: `<h1>{{ .Values.mensaje }}</h1>`

Y define los valores por defecto en `values.yaml` (conserva lo que ya hubiera,
como `image`):
```yaml
replicaCount: 2
mensaje: "Bienvenido a la tienda"
```
`{{ .Values.x }}` es una plantilla de Go: Helm la sustituye por el valor `x`.
Comprueba:
```bash
helm lint .
helm template t . --set replicaCount=4 | grep replicas
```
- `helm lint` revisa el chart.
- `helm template` genera los manifiestos sin instalar nada; `--set` sobrescribe
  un valor. **Qué deberías ver:** `replicas: 4`.
:::

## Paso 3 · Valores por ambiente

:::pista Cómo hacerlo
```bash
printf 'replicaCount: 1\nmensaje: "Tienda (staging)"\n' > ~/charts/tienda/values-staging.yaml
printf 'replicaCount: 2\n' > ~/charts/tienda/values-prod.yaml
```
Con `-f values-staging.yaml`, Helm parte de `values.yaml` y sustituye sólo lo
que ese fichero define. Un único chart; lo que cambia por ambiente vive en su
fichero.
:::

## Paso 4 · Instala staging

```bash
helm install tienda ~/charts/tienda -n staging --create-namespace -f ~/charts/tienda/values-staging.yaml --wait
helm -n staging get values tienda
kubectl -n staging get pods
bash /opt/lab/check.sh
```
`--create-namespace` crea el namespace si no existe. `get values` enseña los
valores con los que se instaló.

**Qué deberías ver:** una réplica y, en el `index.html`, el texto de staging.

## Cómo actuar en una situación así

- `helm upgrade --atomic --wait`: si la actualización no queda sana, Helm
  vuelve atrás solo. Habría evitado el incidente.
- `helm diff upgrade` (un plugin) enseña qué va a cambiar antes de tocar prod.
- Guarda los `values-<amb>.yaml` en git: así sabes qué hay desplegado.

## Si te atascas

- **`helm lint`: `nil pointer evaluating`:** una plantilla usa un valor que no
  está en `values.yaml`.
- **El rollback no termina:** sin `--wait` vuelve enseguida; dale un par de
  minutos y mira `kubectl -n prod get pods`.
- **`cannot re-use a name that is still in use`:** la release de staging ya
  existe; usa `helm upgrade --install`.
