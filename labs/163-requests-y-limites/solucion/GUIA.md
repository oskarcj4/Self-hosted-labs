# Resolución guiada · Lab 163

:::piensa Reserva, techo y prioridad de desalojo
`requests` decide dónde cabe el pod. `limits` decide cuánto puede usar. Y la
combinación de ambos fija su **clase QoS**, que decide a quién se desaloja
primero cuando el nodo se queda sin memoria.
:::

## Paso 1 · La foto actual

:::pista Qué mirar
```bash
kubectl -n catalogo get pods -o custom-columns=POD:.metadata.name,QOS:.status.qosClass
```
- api: sin resources → `BestEffort` (la primera en caer: por eso se cayó).
- calc: requests = limits en cpu (20m) y memoria (32Mi) → `Guaranteed`.
  Guaranteed no significa rápido: tiene garantizado **sólo** el 2 % de un núcleo.
- scraper: `BestEffort`.
:::

## Paso 2 · El estrangulamiento

:::pista Qué mirar
```bash
kubectl -n catalogo logs deploy/calc --tail=3
kubectl -n catalogo exec deploy/calc -- cat /sys/fs/cgroup/cpu.stat
```
`nr_throttled` y `throttled_usec` suben sin parar: el límite de 20m (2 % de un
núcleo) lo frena aunque el nodo esté ocioso.
:::

## Paso 3 · Arreglos

:::pista Cómo hacerlo
```bash
kubectl -n catalogo set resources deploy api --requests=cpu=100m,memory=64Mi --limits=cpu=100m,memory=64Mi
kubectl -n catalogo set resources deploy calc --requests=cpu=200m --limits=cpu=0   # 0 = sin límite
```
LimitRange:
```yaml
apiVersion: v1
kind: LimitRange
metadata: {name: defaults, namespace: catalogo}
spec:
  limits:
  - type: Container
    defaultRequest: {cpu: 50m, memory: 32Mi}
    default:        {cpu: 500m, memory: 128Mi}
```
:::

## Cómo actuar en una situación así

- "Lento con el nodo ocioso" → mira `cpu.stat` antes de culpar al código.
- Cargas críticas: Guaranteed. Tareas prescindibles: BestEffort/Burstable bajo.
- Muchos equipos quitan el límite de CPU y dejan sólo requests; el de memoria, siempre.

## Si te atascas

- `qos.txt` pide la clase **original**: consúltala antes de cambiar nada. Si ya
  cambiaste, mira el manifiesto original en `~/manifiestos/`.
- `set resources --limits=cpu=0` borra el límite en versiones recientes; si no,
  usa `kubectl edit`.
