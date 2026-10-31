# Resolución guiada · Lab 124

:::piensa Antes de tocar nada
Un SIEM no detecta nada solo: junta logs en un sitio. La detección son las
reglas que escribes. Una buena regla responde a "¿qué huella deja esta fase del
ataque en los logs?".
:::

## Paso 1 · ¿Llegan los logs?

**Pregúntate:** ¿qué etiquetas (`job`, `host`) pone promtail a cada línea?

:::pista Cómo comprobarlo
```bash
curl -s http://loki:3100/loki/api/v1/labels | jq
curl -s http://loki:3100/loki/api/v1/label/job/values | jq
```
También desde Grafana (Explore, origen Loki) en el puerto indicado en el ticket.
:::

## Paso 2 · Lee el ataque

**Pregúntate:** ¿qué ve cada fuente? nginx: escaneo de rutas (404) y una subida. auth: fuerza bruta y cuentas nuevas. ¿Y al final?

:::pista Consultas LogQL de prueba
```logql
{job="nginx"} |~ "\" 404 "
{job="nginx"} |~ "POST /api/upload"
{job="auth"} |= "Failed password"
{job="auth"} |~ "useradd.*UID=0"
```
:::

## Paso 3 · De consulta a regla

**Pregúntate:** una alerta necesita un número. ¿Cómo conviertes líneas en un recuento por host?

:::pista Forma de una regla
```yaml
groups:
  - name: deteccion
    rules:
      - alert: FuerzaBrutaSSH
        expr: sum by (host) (count_over_time({job="auth"} |= "Failed password" [5m])) > 10
        for: 0m
        labels: {severity: high, kill_chain: explotacion}
        annotations: {summary: "Fuerza bruta SSH contra {{ $labels.host }}"}
```
Guárdala en `/etc/siem/reglas/deteccion.yml`. Loki recarga las reglas solo.
:::

## Paso 4 · Cubre la Kill Chain

**Pregúntate:** ¿qué fase es cada huella? Reconocimiento (escaneo), entrega (subida de ejecutable), explotación (fuerza bruta), instalación (cuenta UID 0), acciones (volcado y envío de datos).

:::pista Cómo comprobarlo
```bash
curl -s http://loki:3100/prometheus/api/v1/rules | jq '.data.groups[].rules[].name'
curl -s http://loki:3100/prometheus/api/v1/alerts | jq '.data.alerts[] | {a:.labels.alertname, s:.state}'
```
:::

## Paso 5 · soc.md

Explica antivirus vs EDR vs SIEM y los niveles N1/N2/N3 del SOC, en tus palabras.

## Cómo actuar en una situación así

- **Una regla por comportamiento**, no por IP: las IPs cambian, el patrón no.
- **Etiqueta fase y severidad**: ordena la cola del N1.
- Prueba cada regla contra datos reales antes de activarla, o tendrás fatiga de alertas.

## Si te atascas

- La regla no aparece: YAML mal indentado; `python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' fichero`.
- Aparece pero no dispara: ejecuta la `expr` en Grafana y comprueba que el valor supera el umbral.
