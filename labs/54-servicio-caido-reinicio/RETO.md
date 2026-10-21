# Servicio caído tras un reinicio

> Operaciones · systemd · nginx · incidente P1

## Escenario

Son las 03:30. A las 03:05 `web-01` se reinició para aplicar parches y la
tienda no volvió. Tienes el ticket en `~/ticket/INC-2291.txt`.

Lo que sabes: nginx sirve la portada y hace de proxy de `/api/` hacia el
servicio `shop-api` (127.0.0.1:8081). Alguien tocó la configuración ayer y no
recargó. Nadie comprobó si los servicios arrancan solos.

## Objetivos

1. Averigua **por qué** no arranca nginx (no adivines: lee el error).
2. Deja la configuración de nginx válida, sin ficheros sobrantes en
   `sites-enabled/`.
3. `nginx` y `shop-api` en marcha **y habilitados**: el próximo reinicio no
   puede repetir el incidente.
4. `http://127.0.0.1/` devuelve la portada y `http://127.0.0.1/api/health`
   llega a la API pasando por nginx.

## Comandos que te pueden servir

```bash
systemctl status nginx shop-api
systemctl is-enabled nginx shop-api
sudo journalctl -u nginx -b --no-pager | tail -20
sudo nginx -t
ls -la /etc/nginx/sites-enabled/
curl -i http://127.0.0.1/api/health
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
