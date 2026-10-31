# Mini SIEM: detección mapeada a la Cyber Kill Chain

> Monitoreo y SOC · Loki · LogQL · reglas de alerta · Kill Chain

## Escenario

Tres servidores (`web-01`, `ssh-01`, `db-01`) mandan sus logs (nginx y
auth) a un punto central: **Loki**, a través del agente **promtail**. Ahí
eres el SOC. Ahora mismo hay una intrusión en curso que recorre varias fases,
y nadie la está viendo porque no hay ni una regla de detección.

Guía rápida en `~/siem/LEEME.txt` y una plantilla en
`~/siem/ejemplo-regla.yml`. Grafana (opcional) en http://127.0.0.1:3124.

## Conceptos

| Herramienta | Qué ve | Qué hace |
|---|---|---|
| Antivirus | ficheros de un equipo | bloquea lo que coincide con firmas conocidas |
| EDR | comportamiento de un equipo (procesos, red, ficheros) | registra, detecta y permite responder (aislar, matar) |
| SIEM | logs de **muchas** fuentes a la vez | centraliza, correlaciona y alerta |

Cyber Kill Chain (Lockheed Martin): reconocimiento → armamento → entrega →
explotación → instalación → mando y control → acciones sobre objetivos.

## Objetivos

1. Explora los logs con `logcli` (o Grafana) y localiza la intrusión: qué
   IPs, qué hacen y en qué servidor.
2. Escribe en `/etc/siem/reglas/*.yml` al menos **4 reglas de alerta** que
   cubran **4 fases distintas** de la Kill Chain. Cada regla lleva el label
   `kill_chain` con la fase (`reconocimiento`, `entrega`, `explotacion`,
   `instalacion`, `acciones`...).
3. Al menos **3** alertas tienen que estar disparadas (`firing`) con la
   intrusión en curso, una de ellas la fuerza bruta SSH.
4. En `~/soc.md` explica con tus palabras antivirus vs EDR vs SIEM y los
   niveles de un SOC (N1, N2, N3).

## Comandos que te pueden servir

```bash
logcli labels host ; logcli series '{}'
logcli query '{job="nginx"}' --since=10m --limit=50
logcli query '{job="auth", host="ssh-01"} |= "Failed password"' --since=10m
logcli instant-query 'sum by (host) (count_over_time({job="auth"} |= "Failed password" [5m]))'
cp ~/siem/ejemplo-regla.yml /etc/siem/reglas/deteccion.yml && nano /etc/siem/reglas/deteccion.yml
curl -s $LOKI_ADDR/prometheus/api/v1/rules  | jq '.data.groups[].rules[] | {name, health, lastError}'
curl -s $LOKI_ADDR/prometheus/api/v1/alerts | jq '.data.alerts[] | {a: .labels.alertname, state}'
```

> Stack ligero (Loki + promtail + Grafana) en lugar de Wazuh, que necesita
> varios GB de RAM. La idea es la misma: fuentes → agente → central → reglas.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
