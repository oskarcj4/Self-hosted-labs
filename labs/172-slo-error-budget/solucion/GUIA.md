# Resolución guiada · Lab 172

:::piensa ¿Por qué la alerta actual no sirve?
"Más de 0.5 % durante 1 minuto" mide un minuto, pero el SLO mide 30 días.
Un pico de 1 minuto al 5 % gasta el 0.02 % del presupuesto mensual: no merece
despertar a nadie. Una degradación al 1 % durante días sí lo agota, y la
alerta de 1 minuto puede no verla.
:::

## Paso 1 · El presupuesto

:::pista Cómo calcularlo
30 días × 24 h × 60 min = 43 200 min. El 0.5 % son **216 min** de caída total.
Incidentes: 45 + 30 + 75 = 150 min, así que quedan **66**.
:::

## Paso 2 · Los SLI como recording rules

:::pista Qué escribir
```yaml
- record: slo:sli_error:ratio_rate1h
  expr: |
    sum by (job) (rate(http_requests_total{job="checkout",code=~"5.."}[1h]))
    /
    sum by (job) (rate(http_requests_total{job="checkout"}[1h]))
```
Igual para 5m, 30m y 6h.
:::

## Paso 3 · Alertas por burn rate

:::pista Los umbrales
Presupuesto = 0.005. Con 14.4x, el umbral es `14.4 * 0.005 = 0.072` (7.2 % de errores).
Con 6x, `0.03`.
```yaml
- alert: CheckoutSLOBurnRateRapida
  expr: |
    slo:sli_error:ratio_rate1h > (14.4 * 0.005)
    and
    slo:sli_error:ratio_rate5m > (14.4 * 0.005)
  for: 2m
  labels: {severity: page}
```
:::

:::pista ¿Por qué dos ventanas?
Sólo 1 h: tras un pico de 10 min al 50 %, la ventana de 1 h sigue por encima
del umbral casi una hora después de que el problema terminó. La ventana de 5 m
la apaga enseguida. Es el test "pico corto".
:::

## Paso 4 · Recargar

:::pista Cómo hacerlo
```bash
promtool check rules ~/slo/slo-rules.yml && curl -X POST http://127.0.0.1:9090/-/reload
```
:::

## Cómo actuar en una situación así

- Pregunta "¿esta alerta pide que alguien haga algo **ya**?". Si no, no es un page.
- Alerta por síntomas que ve el usuario (errores, latencia), no por causas (CPU).
- Revisa el presupuesto restante antes de un despliegue arriesgado: si queda
  poco, congela cambios.

## Si te atascas

- Los tests fallan por etiquetas: el SLI debe agregarse sólo `by (job)`.
- Escribe un test propio con `promtool test rules` y series como
  `'0+90x180'` (200) y `'0+10x180'` (500) para ver qué dispara y cuándo.
