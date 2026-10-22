# Lab 79 — Triage de un flood: ¿ataque o tráfico legítimo?

## Escenario (detección / respuesta)

Son las 11:40 y `web-79` va lenta. El panel marca un pico enorme de peticiones
HTTP. Antes de bloquear a ciegas (y tumbar a usuarios o al monitor de salud),
haz **triage**: mira el `access.log` y separa el **tráfico malicioso** del
**legítimo de alto volumen**.

En el log conviven:

- Usuarios reales (navegadores, rutas variadas, 200, con `Referer`).
- El **health check interno** desde `10.0.0.50`: muchísimas peticiones a
  `/health`, pero es tuyo y es sano. **No lo bloquees.**
- Un **crawler** (`66.249.66.1`, Googlebot): volumen moderado, legítimo.
- Un **flood distribuido**: muchas IPs de `203.0.113.0/24` y `198.51.100.0/24`
  martillando la misma ruta cara, mismo User-Agent de script, sin `Referer`.

## Objetivos

1. **Analiza** `/var/log/apache2/access.log` y escribe tu análisis en
   `/home/analista/triage.txt`: qué IPs/rangos atacan y **con qué evidencia**
   (tasa de peticiones, User-Agent, ausencia de `Referer`, ruta, códigos).
2. **Rellena la blocklist** `/etc/ddos/blocklist.txt` (una red CIDR por línea)
   **sólo** con los rangos atacantes `203.0.113.0/24` y `198.51.100.0/24`.
3. **No** incluyas en la blocklist al health check `10.0.0.50` ni al crawler
   legítimo: bloquear tu propia monitorización es un autogol.

## Comandos que te pueden servir

```bash
# top de IPs por volumen (¡el top no siempre es el malo!)
awk '{print $1}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head

# agrupar por /24
awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head

# ver User-Agent y ruta de un sospechoso
grep '^203.0.113.' /var/log/apache2/access.log | head

# comparar con un IP legítimo de alto volumen
grep '^10.0.0.50 ' /var/log/apache2/access.log | head
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
