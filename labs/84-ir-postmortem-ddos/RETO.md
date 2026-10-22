# Lab 84 — Respuesta a incidentes: cerrar el DDoS

## Escenario (respuesta a incidentes)

El flood contra `web-84` acaba de amainar y el servicio **ya responde**. Pero
"volver a estar en pie" no es cerrar el incidente: sin medidas, el siguiente
flood te tumba igual. Tienes la evidencia en `/var/log/apache2/access.log` y la
blocklist confirmada en el triage (`/etc/ddos/blocklist.txt`). Cierra el
incidente **de verdad**: mitigación duradera + postmortem.

## Objetivos

1. **Aplica mitigación en el firewall** (`iptables`, cadena `INPUT`). Vale
   cualquiera de las dos (o ambas):
   - **Bloquear** los rangos atacantes de la blocklist (`203.0.113.0/24`,
     `198.51.100.0/24`), **o**
   - **Limitar la tasa** de conexiones nuevas al puerto 80 (módulo `limit`,
     `hashlimit` o `connlimit`).
2. **Escribe el postmortem** en `/home/analista/postmortem.md`, con al menos:
   **Impacto**, **Cronología** (timeline), **Mitigación** aplicada y
   **Prevención** (qué harás para que no se repita).
3. Deja el servicio **sirviendo** (200 en el 80).

## Comandos que te pueden servir

```bash
cat /etc/ddos/blocklist.txt
awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head

# bloquear rangos de la blocklist
while read -r net; do [ -n "$net" ] && sudo iptables -I INPUT -s "$net" -j DROP; done < /etc/ddos/blocklist.txt

# o limitar tasa de conexiones nuevas al 80
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit-above 25/sec --hashlimit-burst 50 \
  --hashlimit-mode srcip --hashlimit-name http -j DROP

sudo iptables -S INPUT
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
