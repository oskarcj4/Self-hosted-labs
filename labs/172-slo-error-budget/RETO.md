# SLO y presupuesto de error

> Observabilidad · SLI · SLO · error budget · burn rate · promtool test rules

## Escenario

El checkout tiene un **SLO**: 99.5 % de peticiones sin error 5xx en una
ventana de 30 días (`~/slo/SLO.md`). La única alerta es "más de 0.5 % de
errores durante 1 minuto": suena cada noche por picos de segundos, y el equipo
ya la silencia sin mirarla.

Conceptos:

- **Presupuesto de error** = 100 % − SLO = 0.5 % de las peticiones (o del tiempo).
- **Burn rate** = ritmo de errores ÷ presupuesto. Con burn rate 1 el
  presupuesto dura justo 30 días; con 14.4 se agota en ~2 días.
- **Alerta multiventana**: dispara si la ventana larga (1 h) supera el umbral
  **y** la corta (5 m) también. La larga da significancia; la corta hace que
  la alerta se apague en cuanto el problema para.

Prometheus corre en `127.0.0.1:9090` y lee las reglas de `~/slo/*-rules.yml`.

## Objetivos

1. Recording rules (`sum by (job)`): `slo:sli_error:ratio_rate5m`, `_rate30m`,
   `_rate1h`, `_rate6h`.
2. Alertas:
   - `CheckoutSLOBurnRateRapida` (`severity: page`): 14.4x en 1 h **y** 5 m, `for` ≤ 5m.
   - `CheckoutSLOBurnRateLenta` (`severity: ticket`): 6x en 6 h **y** 30 m, `for` ≤ 30m.
   - Sin `CheckoutErrores`.
3. `~/slo/presupuesto.txt` con `presupuesto_minutos=` y `restante_minutos=`
   (incidentes en `~/slo/incidentes.txt`).
4. Prometheus con las reglas nuevas cargadas, sin reiniciarlo.

El check ejecuta **tests ocultos** con `promtool test rules`: series
sintéticas de quema rápida, quema lenta, consumo normal y un pico corto.

## Pistas

```bash
promtool check rules ~/slo/slo-rules.yml
curl -X POST http://127.0.0.1:9090/-/reload
curl -s http://127.0.0.1:9090/api/v1/rules | jq '.data.groups[].rules[].name'
curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=slo:sli_error:ratio_rate5m' | jq
```

Escribe tus propios tests (`promtool test rules mis-tests.yml`) con
`input_series` y `alert_rule_test`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
