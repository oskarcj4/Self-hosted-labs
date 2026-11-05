# Resolución guiada · Lab 144

:::piensa ¿Qué es "real"?
No cuentes alertas: léelas. Pregunta por cada una: ¿esto cambia lo que hago
esta noche? Un health check nunca. Un acceso externo con éxito, siempre.
:::

## Paso 1 · Mira la forma del ruido

:::pista Cómo comprobarlo
```bash
soc-stats
```
La regla que más dispara y con nivel bajo (`healthcheck_http`) es ruido puro.
:::

## Paso 2 · Encuentra la cadena

**Pregúntate:** ¿hay un origen que aparece en varias alertas de nivel alto?

:::pista Cómo comprobarlo
```bash
jq -c 'select(.nivel>=10)' /var/log/soc/alertas.jsonl
jq -r 'select(.nivel>=10).src_ip' /var/log/soc/alertas.jsonl | sort -u
```
Todas salen de `203.0.113.7`: acceso → webshell → escalada. Esa es la historia.
:::

## Paso 3 · No te comas un falso negativo

:::pista Ojo con el escáner
`vuln_scan` desde `10.0.5.5` es nivel 4 y dice "ventana aprobada CHG-2271".
Es el equipo de pentest: se vigila, no se escala, y **no se silencia** (si un
día viene de otra IP, quieres verlo).
:::

## Paso 4 · Escribe el triage y silencia el ruido

:::pista Cómo hacerlo
```bash
jq -r 'select(.nivel>=10).id' /var/log/soc/alertas.jsonl | sort | paste -sd,
cat > ~/triage.txt <<'T'
ip_atacante=203.0.113.7
alertas_reales=7031,7032,7033
regla_ruidosa=healthcheck_http
T
sudo tee -a /etc/soc/supresiones.txt <<<'healthcheck_http'
```
:::

## Cómo actuar en una situación así

- El triage es decidir, no clasificar por gusto: cada alerta accionable lleva
  una acción; cada regla ruidosa, una justificación para bajarla.
- Mide tu ratio señal/ruido: si el 90% nunca se acciona, el SOC no escala.

## Si te atascas

- `alertas_reales` no cuadra: usa exactamente los ids que da
  `jq -r 'select(.nivel>=10).id'`, ordenados.
- No pongas `vuln_scan` en supresiones: el validador lo marca como error.
