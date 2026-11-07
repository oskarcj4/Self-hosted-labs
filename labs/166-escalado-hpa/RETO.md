# Escalado con HPA

> Kubernetes · HorizontalPodAutoscaler · metrics-server · requests · behavior

## Escenario

En el pico de ayer, `web` (namespace `web`) se quedó con **1 réplica** y la
latencia se disparó. Hay un HPA (`minReplicas 1`, `maxReplicas 5`, objetivo 50 %
de CPU)… que no hizo nada.

Cómo decide el HPA:

```
réplicas deseadas = ceil( réplicas actuales × uso actual / uso objetivo )
uso (%) = CPU usada (metrics-server) / CPU pedida en requests
```

Sin `requests.cpu` no hay denominador: el HPA no puede calcular nada y se queda
quieto (`TARGETS <unknown>/50%`).

El HPA también puede **oscilar**: sube con un pico, baja en cuanto se calma,
vuelve a subir… `behavior.scaleDown.stabilizationWindowSeconds` hace que espere
antes de bajar.

## Objetivos

1. `~/hpa.txt` con `causa=` (por qué no escalaba).
2. El contenedor `web` declara `requests.cpu` (p. ej. `100m`) y `limits.memory`.
3. HPA con `behavior.scaleDown.stabilizationWindowSeconds` >= 60.
4. Con carga, el HPA sube a >= 2 réplicas (el check lanza su propia carga).

## Pistas

```bash
kubectl -n web get hpa
kubectl -n web describe hpa web | tail -8      # FailedGetResourceMetric...
kubectl top pod -n web
kubectl -n web set resources deploy web --requests=cpu=100m --limits=memory=64Mi
kubectl -n web edit hpa web
kubectl -n web scale deploy carga --replicas=3; kubectl -n web get hpa -w
```

## Cuando creas que terminaste

Deja `carga` en 0 réplicas y:

```bash
bash /opt/lab/check.sh
```
