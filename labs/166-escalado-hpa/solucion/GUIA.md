# Resolución guiada · Lab 166

:::piensa Un porcentaje necesita denominador
El HorizontalPodAutoscaler (HPA) de CPU no trabaja en núcleos, sino en **% de
lo pedido**: uso real (que le da metrics-server) dividido entre
`requests.cpu`. Sin `requests.cpu` no hay denominador: el HPA no puede
calcular nada y no hace nada.
:::

**El plan:** (1) ver por qué no escala, (2) declarar los recursos, (3) evitar
que oscile y (4) probarlo con carga.

## Paso 1 · Diagnóstico

:::pista Cómo hacerlo
```bash
kubectl -n web get hpa
kubectl -n web describe hpa web | tail -8
kubectl top pod -n web
```
- `TARGETS` es "uso actual / objetivo".
- `describe` enseña los eventos del HPA al final.
- `kubectl top` muestra el uso real de CPU y memoria (lo mide metrics-server).

**Qué deberías ver:** `TARGETS <unknown>/50%` y un evento
`FailedGetResourceMetric … missing request for cpu`. `kubectl top` sí da un
uso: el dato existe, pero falta con qué compararlo.
```bash
echo "causa=faltan requests de cpu: sin ellos el HPA no puede calcular el porcentaje" > ~/hpa.txt
```
:::

## Paso 2 · Declara los recursos

:::pista Cómo hacerlo
```bash
kubectl -n web set resources deploy web --requests=cpu=100m --limits=memory=64Mi
kubectl -n web rollout status deploy web
```
- `set resources` cambia los recursos del contenedor del Deployment.
  `100m` son 100 milinúcleos: una décima de CPU.
- Cambiar el Deployment crea pods nuevos; `rollout status` espera a que
  terminen de sustituir a los viejos.

En un rato, `kubectl -n web get hpa` mostrará un porcentaje en `TARGETS`.
:::

## Paso 3 · Que no oscile

**Pregúntate:** si la carga sube y baja a cada minuto, ¿qué hace el HPA?

:::pista Cómo hacerlo
Sube y baja réplicas sin parar. Una ventana de estabilización hace que espere
antes de **bajar**:
```bash
kubectl -n web patch hpa web --type=merge \
  -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":120}}}}'
```
`patch --type=merge` mezcla ese trozo de JSON con el objeto existente, sin
reescribirlo entero. Con 120 s, el HPA mira el máximo de réplicas recomendadas
en los últimos 2 minutos antes de reducir.
:::

## Paso 4 · Pruébalo con carga

:::pista Cómo hacerlo
```bash
kubectl -n web scale deploy carga --replicas=3
kubectl -n web get hpa -w
```
`-w` (*watch*) se queda mostrando los cambios; sal con Ctrl+C.

**Qué deberías ver:** el porcentaje subiendo por encima del 50 % y `REPLICAS`
pasando a 2 o más en uno o dos minutos. El HPA calcula
`réplicas = ceil(actuales × uso / objetivo)`: con 1 réplica al 150 %, pide 3.

Quita la carga y valida (el check lanza la suya):
```bash
kubectl -n web scale deploy carga --replicas=0
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- `requests` realistas: muy altos y nunca llegarás al objetivo; muy bajos y
  escalarás por nada.
- La CPU sirve para cargas que gastan CPU. Para colas o eventos, KEDA (escala
  por longitud de cola, incluso a 0).
- `maxReplicas` también protege: un bucle o un ataque no te lleva a 200 pods.

## Si te atascas

- **`kubectl top`: `metrics not available yet`:** espera un minuto tras
  arrancar los pods.
- **Sube muy despacio:** el HPA reevalúa cada 15 s y metrics-server mide cada
  15-60 s. Dale un par de minutos.
- **Sigue en `<unknown>`:** comprueba que el contenedor tiene la petición:
  `kubectl -n web get deploy web -o jsonpath='{..resources}'`.
