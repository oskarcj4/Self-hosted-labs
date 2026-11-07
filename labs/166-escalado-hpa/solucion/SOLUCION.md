# Solución — Escalado con HPA

**Causa**: el contenedor `web` no declaraba `requests.cpu`. El HPA mide el uso
como porcentaje del request; sin él marca `<unknown>` y no actúa
(`FailedGetResourceMetric: missing request for cpu`).

```bash
kubectl -n web set resources deploy web --requests=cpu=100m --limits=memory=64Mi
kubectl -n web patch hpa web --type=merge -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds":120}}}}'
```

```yaml
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120   # mira 2 min de recomendaciones antes de bajar
```

## Por qué

- `deseadas = ceil(actuales × uso / objetivo)`: con 1 réplica al 180 % de 100m y
  objetivo 50 %, pide `ceil(1 × 180 / 50) = 4`.
- La ventana de estabilización toma la recomendación **más alta** de los últimos
  N segundos al bajar: evita el yo-yo con picos intermitentes.

## Más allá del lab

- KEDA: `ScaledObject` por longitud de cola (RabbitMQ, Kafka, Redis, SQS), cron
  o métricas de Prometheus; permite escalar a 0.
- Combina HPA (réplicas) con Cluster Autoscaler (nodos) para picos grandes.
- No mezcles HPA y VPA sobre la misma métrica de CPU.
