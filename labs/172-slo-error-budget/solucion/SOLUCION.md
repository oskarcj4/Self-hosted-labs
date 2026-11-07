# Solución — SLO y presupuesto de error

## Cálculo

| Dato | Valor |
|------|-------|
| Ventana | 30 días = 43 200 min |
| Presupuesto (0.5 %) | 216 min |
| Consumido (45 + 30 + 75) | 150 min |
| Restante | 66 min |

`~/slo/presupuesto.txt`:
```
presupuesto_minutos=216
restante_minutos=66
```

## Reglas

Cuatro recording rules `slo:sli_error:ratio_rate{5m,30m,1h,6h}` con
`sum by (job)` y dos alertas (ver `solve.sh` para el fichero completo):

| Alerta | Condición | Severidad | Gasta del presupuesto |
|--------|-----------|-----------|----------------------|
| CheckoutSLOBurnRateRapida | 1h > 0.072 **y** 5m > 0.072 | page | 2 % en 1 h |
| CheckoutSLOBurnRateLenta | 6h > 0.03 **y** 30m > 0.03 | ticket | 5 % en 6 h |

```bash
promtool check rules ~/slo/slo-rules.yml
curl -X POST http://127.0.0.1:9090/-/reload
```

## Qué comprueban los tests ocultos

| Escenario | Esperado |
|-----------|----------|
| 10 % de errores | page a los 30 min y ticket a la hora |
| 1 % de errores durante 8 h | nada (la alerta vieja habría sonado) |
| 4 % de errores durante 10 h | ticket, sin page |
| Pico de 10 min al 50 % y luego 0 % | page apagada a los 25 min (la ventana de 5 m ya está a 0) |

## Por qué

- La alerta por burn rate relaciona el ruido con el **coste** real para el SLO.
- 14.4x en 1 h = 2 % del presupuesto mensual: si sigue así, se agota en ~2 días.
- Las recording rules evitan recalcular `rate()` sobre 6 h en cada evaluación.

## Más allá del lab

- Un tercer nivel: 1x en 3 días, para tickets de baja prioridad.
- Herramientas que generan estas reglas desde un YAML de SLO: Sloth, Pyrra.
- Mide también un SLO de latencia (p. ej. el 99 % por debajo de 300 ms) con
  los buckets del histograma.
