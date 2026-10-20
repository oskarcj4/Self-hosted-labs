# Día 04 — Desactivar el listado de directorios

> 30 días de DevSecOps · Linux · Exposición e higiene web

## Escenario

`files-01` es el centro de descargas público. Un cliente avisa de que, si
quitas el nombre del fichero de la URL, nginx enseña **todo el contenido de la
carpeta**… incluida una subcarpeta `internal/` con precios mayoristas que
nunca debió ser descubrible.

## Objetivos

1. Ningún directorio del sitio debe mostrar un listado ("Index of …"):
   `/downloads/`, `/downloads/drivers/`, `/downloads/internal/`, `/assets/`…
2. Pedir `/downloads/` debe devolver **403 o 404**.
3. Los ficheros enlazados deben seguir descargándose (200): el manual, las
   notas de versión, el driver, `/assets/site.css` y la portada.
4. La configuración efectiva de nginx no debe contener `autoindex on` en
   ningún sitio, y nginx debe quedar válido y activo.

> Pista: en nginx la directiva se **hereda**. Mira en todos los niveles:
> `http`, `server` y cada `location`.

## Comandos que te pueden servir

```bash
IP=$(hostname -I | awk '{print $1}')
curl -s http://$IP/downloads/ | head
sudo nginx -T | grep -n autoindex       # config efectiva, con el nombre de cada fichero
ls /etc/nginx/conf.d/ /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
