# HTTP con curl: lee lo que responde el servidor

> Redes · curl -I · curl -v · curl -w · códigos de estado

## Escenario

"La app móvil no carga los pedidos" (`~/ticket/WEB-127.txt`). Antes de
tocar nada, el equipo de front quiere saber qué devuelve **exactamente**
cada ruta de `http://tienda.lab`. Sin navegador: el navegador sigue
redirecciones, cachea y esconde cabeceras. `curl` te enseña la verdad.

| Familia | Significado | Ejemplos |
|---|---|---|
| 2xx | bien | 200 OK, 201 Created |
| 3xx | ve a otro sitio | 301 permanente, 302 temporal (mira `Location`) |
| 4xx | el cliente pidió mal | 401 sin autenticar, 403 prohibido, 404 no existe, 429 demasiadas |
| 5xx | el servidor falló | 500 error interno, 502 el proxy no llega al backend, 503 no disponible, 504 timeout |

## Objetivos

1. Rellena `~/codigos.txt` con el código de `/catalogo`, `/admin`,
   `/interno`, `/no-existe` y `/api/pedidos`, y a dónde redirige
   `/catalogo` (`redireccion=`). Formato en el ticket.
2. `/api/pedidos` da 502: con `curl -v`, el `error.log` de nginx y `ss`,
   descubre por qué y arréglalo **sin tocar el backend**.
3. Mide con `curl -w` cuánto tarda en empezar a responder y anótalo como
   `ttfb_pedidos=<segundos>`.

## Comandos que te pueden servir

```bash
curl -I http://tienda.lab/catalogo                     # sólo cabeceras
curl -s -o /dev/null -w '%{http_code}\n' http://tienda.lab/admin
curl -v http://tienda.lab/api/pedidos                  # conversación completa
curl -s -o /dev/null -w 'dns=%{time_namelookup} conn=%{time_connect} ttfb=%{time_starttransfer} total=%{time_total}\n' http://tienda.lab/api/pedidos
sudo tail /var/log/nginx/error.log
sudo ss -ltnp
sudo nginx -t && sudo systemctl reload nginx
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
