# Resolución guiada · Lab 165

:::piensa Lista blanca, no lista negra
Sin políticas, en Kubernetes todo pod habla con todo pod, de cualquier
namespace. Las NetworkPolicy no tienen reglas de "denegar": en cuanto un pod
queda seleccionado por alguna política de tipo `Ingress`, **sólo** acepta lo
que alguna política permita. Así que primero se aísla todo y luego cada
política **suma** un permiso. Si un flujo no está escrito, no existe.
:::

**El plan:** (1) medir, (2) negar por defecto, (3) abrir los tres flujos y
(4) comprobar la matriz.

## Paso 1 · Mide antes de tocar

:::pista Cómo hacerlo
```bash
probar-red
kubectl -n tienda get pods --show-labels
kubectl get ns --show-labels
```
- `probar-red` es un comando del lab: prueba cada origen contra cada destino
  y marca `MAL` lo que no debería pasar (o lo que debería y no pasa).
- `--show-labels` enseña las etiquetas: las políticas eligen pods y
  namespaces por etiquetas, no por nombre. Cada namespace tiene una
  automática: `kubernetes.io/metadata.name=<nombre>`.

**Qué deberías ver:** todo `PERMITIDO`, incluido `externo/atacante -> db`.
:::

## Paso 2 · Negar por defecto

:::pista Cómo hacerlo
`~/politicas/tienda.yaml`, primera parte:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: tienda}
spec:
  podSelector: {}
  policyTypes: [Ingress]
```
- `podSelector: {}` (vacío) selecciona **todos** los pods del namespace.
- `policyTypes: [Ingress]` sin ninguna regla `ingress`: no se permite ningún
  tráfico de entrada.

Si la aplicas sola, `probar-red` mostrará todo bloqueado, también lo que
debía funcionar.
:::

## Paso 3 · Abre sólo lo necesario

:::pista Cómo hacerlo
Añade al mismo fichero (los documentos YAML se separan con `---`):
```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: api-desde-frontend-y-monitoring, namespace: tienda}
spec:
  podSelector: {matchLabels: {app: api}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: frontend}}
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: monitoring}}
    ports: [{port: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: db-desde-api, namespace: tienda}
spec:
  podSelector: {matchLabels: {app: db}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector: {matchLabels: {app: api}}
    ports: [{port: 5432}]
```

| Pieza | Qué significa |
|---|---|
| `spec.podSelector` | A qué pods se **aplica** la política (el destino). |
| `ingress[].from` | Desde dónde se permite. Cada elemento de la lista es una alternativa (**O**). |
| `podSelector` dentro de `from` | Pods de **este mismo** namespace con esa etiqueta. |
| `namespaceSelector` | Cualquier pod de los namespaces con esa etiqueta. |
| `ports` | El puerto del **pod** destino (no el del Service). |

**El detalle que más confunde:** aquí `podSelector` y `namespaceSelector` son
**dos elementos** de `from` (cada uno con su guion): frontend **o** cualquier
pod de monitoring. Si los pusieras en un mismo elemento, significaría "pods
con la etiqueta de frontend **y** que estén en monitoring", que no existen.
```bash
kubectl apply -f ~/politicas/
kubectl -n tienda get networkpolicy
```
:::

## Paso 4 · Comprueba

```bash
probar-red
bash /opt/lab/check.sh
```
**Qué deberías ver:** los tres flujos `PERMITIDO`, todo lo demás `BLOQUEADO`, y
ninguna línea `MAL`.

## Cómo actuar en una situación así

- Empieza por *default-deny* de entrada. El siguiente paso es el de salida
  (`Egress`), y ahí hay que permitir el DNS (kube-dns, puerto 53) o nada
  resolverá nombres.
- Basa las reglas en etiquetas estables (`app`,
  `kubernetes.io/metadata.name`), no en IPs: los pods cambian de IP.
- Las NetworkPolicy necesitan un plugin de red que las aplique (Calico,
  Cilium… en k3s viene uno). Sin él, se aceptan y no hacen nada.

## Si te atascas

- **`monitoring` no llega:** el `namespaceSelector` está en el mismo elemento
  que el `podSelector` de frontend (sería **Y**). Sepáralos.
- **Todo bloqueado tras tus políticas:** revisa `ports`; es el puerto del pod.
- **`error validating data`:** la sangría del YAML; `kubectl apply --dry-run=client -f …`
  lo comprueba sin aplicar.
