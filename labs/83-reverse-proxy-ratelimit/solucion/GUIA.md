# Resolución guiada · Lab 83

:::piensa Antes de tocar nada
El reverse proxy es tu **borde**: todo pasa por él antes de llegar al backend. Es el sitio natural para filtrar. nginx limita peticiones con un "cubo con fichas" (*token bucket*): cada IP gasta fichas al pedir; si se queda sin fichas más rápido de lo que se rellenan, se le corta. `rate` es el ritmo de relleno; `burst` el tamaño del cubo.
:::

## Paso 0 · Mídelo sin límite

```bash
ab -n 500 -c 50 http://127.0.0.1/     # casi todo 200: nada frena la ráfaga
```

## Paso 1 · Define la zona (contexto http)

**Pregúntate:** ¿por qué clave limito? Por IP de cliente → `$binary_remote_addr`.

:::pista Cómo hacerlo
```bash
sudo sed -i '/^http {/a \    limit_req_zone $binary_remote_addr zone=web:10m rate=10r/s;\n    limit_req_status 429;' /etc/nginx/nginx.conf
```
`zone=web:10m` reserva 10 MB para el estado por IP (~160k IPs). `rate=10r/s` = 10 peticiones por segundo por IP de media.
:::

## Paso 2 · Aplica el límite en la location

:::pista Cómo hacerlo
Edita `/etc/nginx/sites-enabled/default`, dentro de `location / {`:
```nginx
location / {
    limit_req zone=web burst=20 nodelay;
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```
`burst=20` permite picos cortos (cola de 20); `nodelay` sirve el pico al instante y corta lo que pase.
:::

## Paso 3 · Validar y recargar

```bash
sudo nginx -t
sudo service nginx reload
```

## Paso 4 · Mide con límite

```bash
ab -n 500 -c 50 http://127.0.0.1/     # ahora aparecen 429/503: el exceso se corta
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/   # una petición normal: 200
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **X-Real-IP / X-Forwarded-For**: si hay otro proxy o CDN por delante, limita por
  la IP real (`real_ip_header`) o limitarás a tu propio proxy.
- Pon límites distintos por ruta: `/login` y `/buscar` más estrictos que `/static`.
- nginx también sirve contra **Slowloris** (lab 81): bufferiza la petición antes
  de pasarla al backend, así las conexiones lentas las aguanta el proxy.
- **Cloudflare / CDN real**: cuando el flood supera tu ancho de banda de entrada,
  ningún proxy local basta —el tráfico ya saturó tu línea—. Ahí necesitas un
  borde distribuido (Cloudflare, Fastly, Akamai) que absorba lejos de tu origen.
  El reverse proxy local y la CDN no compiten: se complementan.
- Alternativas al mismo patrón: HAProxy (`stick-table`), Traefik (middleware
  rate-limit), o crowdsec/Anubis para bots.
