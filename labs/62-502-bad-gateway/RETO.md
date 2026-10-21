# 502 Bad Gateway (y sus primos 403 y 504)

> Operaciones · nginx · reverse proxy · error.log

## Escenario

Tras desplegar la v2 de `gestion`, nginx devuelve errores en las tres partes
del sitio. Lee `~/ticket/INC-6202.txt`.

| URL | Error |
|---|---|
| `/` | 502 Bad Gateway |
| `/static/logo.txt` | 403 Forbidden |
| `/api/informe` | 502... y, cuando arregles el 502, 504 Gateway Time-out |

Cada código te dice **quién** falla: el navegador habla con nginx, y nginx
habla con la app o con el disco. El sitio donde mirar es `error.log` de nginx.

## Objetivos

1. `/` responde 200 a través de nginx. **No** cambies el puerto de la app:
   el 8001 es intencionado.
2. `/static/logo.txt` responde 200, sin dejar nada escribible por todos.
3. `/api/informe` (tarda ~12 s) responde 200.
4. El timeout largo, **sólo** para el informe: el resto del sitio debe seguir
   fallando rápido si la app se cuelga.

## Comandos que te pueden servir

```bash
curl -i http://127.0.0.1/ ; curl -i http://127.0.0.1/static/logo.txt
sudo tail -f /var/log/nginx/error.log          # en otra pestaña, mientras pruebas
sudo ss -ltnp | grep -E '800[01]'
cat /etc/gestion/gestion.env
sudo nginx -T | less                           # config completa efectiva
namei -l /srv/gestion/static/logo.txt          # permisos de cada directorio de la ruta
sudo nginx -t && sudo systemctl reload nginx
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
