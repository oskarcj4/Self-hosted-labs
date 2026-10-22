# Resolución guiada · Lab 84

:::piensa Antes de tocar nada
Un incidente no se cierra cuando el servicio vuelve: se cierra cuando **no puede volver a pasar igual** y queda **documentado** para el siguiente turno. Dos entregables: la mitigación duradera (firewall) y el postmortem (sin culpables, con acciones).
:::

## Paso 1 · Confirma el alcance con la evidencia

```bash
awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head
cat /etc/ddos/blocklist.txt
```

## Paso 2 · Mitigación duradera en el firewall

**Pregúntate:** ¿bloqueo a los atacantes conocidos o limito a todos por tasa? Lo ideal: ambas. Bloqueo = preciso contra lo conocido; rate limit = red de seguridad contra lo nuevo.

:::pista Opción A · bloquear los rangos de la blocklist
```bash
while read -r net; do
  [ -n "$net" ] && sudo iptables -I INPUT -s "$net" -j DROP
done < /etc/ddos/blocklist.txt
```
:::

:::pista Opción B · limitar la tasa de conexiones nuevas al 80
```bash
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit-above 25/sec --hashlimit-burst 50 \
  --hashlimit-mode srcip --hashlimit-name http -j DROP
```
Cada IP que abra más de 25 conexiones nuevas/s al 80 (tras un burst de 50) se corta.
:::

```bash
sudo iptables -S INPUT
```

## Paso 3 · Escribe el postmortem

:::pista Plantilla
```bash
cat > /home/analista/postmortem.md <<'EOF'
# Postmortem — DDoS contra web-84 (10/10/2026)

## Impacto
~40 min de 503 intermitentes en /buscar. Sin pérdida de datos.

## Cronología
- 11:30 pico de peticiones a /buscar desde 203.0.113.0/24 y 198.51.100.0/24.
- 11:35 saturación de workers, 503 a usuarios reales.
- 11:40 triage: identificados los rangos; health check y crawler descartados.
- 11:50 mitigación aplicada; servicio estable.

## Mitigación
- Bloqueo de 203.0.113.0/24 y 198.51.100.0/24 en iptables.
- Rate limit hashlimit de 25/s por IP en el puerto 80.

## Prevención (seguimiento)
- Rate limit permanente en el reverse proxy (lab 83).
- mod_evasive + reqtimeout en Apache (labs 80/81).
- Alerta automática por tasa de 5xx.
- Evaluar CDN/Cloudflare si el volumen supera el ancho de banda de entrada.
EOF
```
:::

## Paso 4 · Verifica

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/   # 200
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Persiste** las reglas (`iptables-save`) o se pierden al reiniciar.
- El postmortem es **sin culpa** (*blameless*): busca causas y acciones, no
  responsables. Cada acción con dueño y fecha.
- Durante el incidente: comunica (status page), mide (5xx, latencia), mitiga por
  capas (firewall → proxy → WAF), y sólo después documenta en frío.
- Revisa los **falsos positivos** del bloqueo por rango: si un /24 tenía
  usuarios legítimos, acótalo o pásalo a rate limit.
