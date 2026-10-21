# Solución — 502 / 403 / 504

Deja `sudo tail -f /var/log/nginx/error.log` abierto en otra pestaña: cada
error explica su causa.

## 502: nginx no conecta con la app

```
connect() failed (111: Connection refused) while connecting to upstream, upstream: "http://127.0.0.1:8000/"
```

```bash
sudo ss -ltnp | grep gestion     # 127.0.0.1:8001  users:(("gestion",...))
cat /etc/gestion/gestion.env     # PORT=8001
```

La app se movió al 8001 y el `upstream` de nginx sigue apuntando al 8000.

```bash
sudo sed -i 's/server 127.0.0.1:8000;/server 127.0.0.1:8001;/' /etc/nginx/sites-available/gestion
```

## 403: nginx no puede leer el fichero

```
open() "/srv/gestion/static/logo.txt" failed (13: Permission denied)
```

```bash
namei -l /srv/gestion/static/logo.txt
# drwx------ root root static        <- www-data no puede ni entrar
# -rw------- root root logo.txt
```

nginx sirve los ficheros como `www-data`. Necesita `x` en cada directorio de
la ruta y `r` en el fichero. **No** hace falta 777:

```bash
sudo chmod 0755 /srv/gestion/static
sudo chmod 0644 /srv/gestion/static/*
```

Para que el próximo despliegue no lo vuelva a romper, el pipeline debe copiar
con permisos explícitos (`install -m 0644`, `rsync --chmod=D755,F644`) en vez
de depender del `umask` de root.

## 504: nginx se cansó de esperar

```
upstream timed out (110: Connection timed out) while reading response header from upstream
```

`proxy_read_timeout 5s` y el informe tarda 12 s. Sube el timeout **sólo** en
esa ruta:

```nginx
    location /api/informe {
        proxy_pass http://gestion_app;
        proxy_set_header Host $host;
        proxy_read_timeout 30s;
    }
```

Si subes el timeout de `location /`, cuando la app se cuelgue cada petición
del sitio retiene una conexión durante 30 s, y se agotan los workers.

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -s http://127.0.0.1/ ; curl -s http://127.0.0.1/static/logo.txt ; time curl -s http://127.0.0.1/api/informe
```

## Lecciones

| Código | Quién falla | Dónde mirar |
|---|---|---|
| 502 | nginx no conecta con el upstream (no escucha, puerto mal, crash) | `error.log`, `ss -ltnp` |
| 503 | upstream sin servidores disponibles / app sobrecargada | `error.log`, la app |
| 504 | el upstream conecta pero tarda más que `proxy_read_timeout` | `error.log`, latencia de la app |
| 403 | nginx no puede leer el fichero (permisos, `deny`, sin index) | `error.log`, `namei -l` |

- Un cambio de puerto en la app es un cambio también en el proxy (y en el
  firewall y en la monitorización). Revisa los changelogs.
- Timeouts largos sólo donde hacen falta. Lo mejor es que el informe pesado
  sea asíncrono (encolar el trabajo y consultar el resultado después).
