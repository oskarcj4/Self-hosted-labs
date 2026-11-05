# Resolución guiada · Lab 143

:::piensa El ruido tapa la señal
Un DDoS que tira la web es escandaloso y fácil de ver. Por eso es la tapadera
perfecta. Tu trabajo no termina cuando la web responde: termina cuando sabes
qué pasó *mientras* la web se caía.
:::

## Paso 1 · ¿Quién inunda?

:::pista Cómo comprobarlo
```bash
sudo awk '$7=="/"{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
sudo grep -m1 '10.143.0.66' /var/log/nginx/access.log   # primera línea del flood -> 02:11
```
Apunta `ip_ddos=` y la hora de inicio para la timeline.
:::

## Paso 2 · Contén la inundación

**Pregúntate:** ¿qué clave identifica a cada cliente y dónde se declara la zona?

:::pista Cómo hacerlo
```bash
sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=raiz:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conx:10m;
limit_req_status  429;
limit_conn_status 429;
N
```
Luego, dentro de `location /`:
```nginx
limit_req zone=raiz burst=10 nodelay;
limit_conn conx 10;
```
`sudo nginx -t && sudo systemctl reload nginx`. `/static/` es otra `location`:
no hereda el límite.
:::

## Paso 3 · ¿Qué tapaba el ruido?

:::pista Cómo comprobarlo
```bash
sudo find / -xdev -newermt "$(date +%F) 02:10" ! -newermt "$(date +%F) 02:20" \
     -type f 2>/dev/null | grep -v -e /proc -e /sys
```
Salen el cron, el beacon y `fsociety00.dat`. Lee el cron para ver qué lanza.
:::

## Paso 4 · Documenta antes de borrar

:::pista Cómo hacerlo
Rellena `~/hallazgos.txt` (incluye el `sha256sum` del `.dat`) y `~/timeline.txt`
con 02:11 (DDoS) y 02:14 (persistencia). Primero se documenta; luego se limpia.
:::

## Paso 5 · Erradica, conserva la evidencia

:::pista Cómo hacerlo
```bash
sudo rm -f /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon
sudo systemctl restart cron
sudo pkill -f fsociety-beacon || true
```
No borres `fsociety00.dat`: es evidencia.
:::

## Cómo actuar en una situación así

- Todo pico de tráfico anómalo abre una ventana temporal: audítala en disco,
  cuentas, cron, timers y `authorized_keys`.
- El hash del artefacto va al informe (cadena de custodia), no a la papelera.

## Si te atascas

- Sale 503 en vez de 429: falta `limit_req_status 429`.
- `nginx -t` dice "zone unknown": la zona debe ir en contexto `http` (`conf.d/`),
  no dentro de `server`.
- El beacon vuelve: ¿quitaste el `cron.d` *y* recargaste cron?
