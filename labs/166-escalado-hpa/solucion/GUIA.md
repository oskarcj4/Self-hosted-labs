# Resolución guiada · Lab 166

:::piensa Un porcentaje necesita denominador
El HPA de CPU trabaja en **% de lo pedido** (`requests`), no en núcleos
absolutos. Sin `requests.cpu`, metrics-server da el uso pero no hay contra qué
compararlo.
:::

## Paso 1 · Diagnóstico

:::pista Qué mirar
```bash
kubectl -n web get hpa                     # TARGETS <unknown>/50%
kubectl -n web describe hpa web | tail -5  # missing request for cpu
```
:::

## Paso 2 · Arreglo

:::pista Cómo hacerlo
```bash
kubectl -n web set resources deploy web --requests=cpu=100m --limits=memory=64Mi
kubectl -n web patch hpa web --type=merge \
  -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":120}}}}'
```
:::

## Paso 3 · Prueba con carga

:::pista Cómo hacerlo
```bash
kubectl -n web scale deploy carga --replicas=3
kubectl -n web get hpa -w        # sube a los ~30-60 s
kubectl -n web scale deploy carga --replicas=0
```
Al quitar la carga, el HPA espera la ventana de estabilización antes de bajar.
:::

## Cómo actuar en una situación así

- HPA + requests realistas: si `requests` es muy alto, nunca llegarás al objetivo;
  si es muy bajo, escalarás por nada.
- Escalar por CPU sirve para cargas CPU-bound. Para colas o eventos, KEDA
  (escala por longitud de cola, incluso a 0).

## Si te atascas

- `kubectl top` dice `metrics not available yet`: espera ~1 min tras arrancar.
- Sube muy lento: el HPA reevalúa cada 15 s y metrics-server muestrea cada ~15-60 s.
