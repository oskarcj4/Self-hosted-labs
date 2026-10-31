# Resolución guiada · Lab 127

:::piensa Antes de tocar nada
El navegador esconde casi todo. `curl` te enseña el código, las cabeceras y el
tiempo de cada fase. Cada código cuenta una historia distinta.
:::

## Paso 1 · Códigos

**Pregúntate:** ¿qué diferencia hay entre 301, 401, 403, 404 y 502?

:::pista Cómo comprobarlo
```bash
for p in /catalogo /admin /interno /no-existe /api/pedidos; do
  echo "$p $(curl -s -o /dev/null -w '%{http_code}' http://tienda.lab$p)"
done
```
- 3xx: ve a otro sitio. 401: identifícate. 403: identificado o no, no puedes.
- 404: no existe. 502: el proxy no consigue respuesta válida del backend.
:::

## Paso 2 · ¿A dónde redirige?

:::pista Cómo comprobarlo
```bash
curl -sI http://tienda.lab/catalogo | grep -i location
```
Escribe todo en `~/codigos.txt` (`catalogo=`, `admin=`, `interno=`, `no_existe=`, `pedidos=`, `redireccion=`).
:::

## Paso 3 · ¿Por qué el 502?

**Pregúntate:** ¿a qué puerto envía nginx y en cuál escucha el backend?

:::pista Cómo comprobarlo
```bash
curl -sv http://tienda.lab/api/pedidos -o /dev/null
sudo tail -2 /var/log/nginx/error.log      # connect() failed ... upstream: 127.0.0.1:8001
sudo ss -ltnp | grep python
```
:::

## Paso 4 · Arregla y mide

:::pista Cómo hacerlo
```bash
sudo sed -i 's/127.0.0.1:8001/127.0.0.1:8081/' /etc/nginx/sites-available/tienda
sudo nginx -t && sudo systemctl reload nginx
curl -s -o /dev/null -w 'ttfb=%{time_starttransfer}\n' http://tienda.lab/api/pedidos
```
Añade `ttfb_pedidos=` a `~/codigos.txt`.
:::

## Cómo actuar en una situación así

- **502/504 = mira el error.log del proxy**: dice exactamente a qué upstream no llegó.
- `-w` con `time_namelookup`, `time_connect`, `time_starttransfer` separa DNS, red y backend.
- `curl -v` muestra la petición y la respuesta completas.

## Si te atascas

- `ttfb` sale muy bajo y el check falla: mediste antes de que nginx recargara; repite.
- `nginx -t` falla: revisaste otro fichero; `nginx -T | grep proxy_pass`.
