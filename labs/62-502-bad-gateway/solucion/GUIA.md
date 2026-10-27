# Resolución guiada · 502 / 403 / 504

:::piensa Antes de tocar nada
Cada código HTTP de nginx dice **quién** falla. El navegador habla con nginx, y
nginx habla con la app (upstream) o con el disco. La fuente de la verdad es
`error.log`: cada línea nombra su causa. Deja esto abierto en otra pestaña:
```bash
sudo tail -f /var/log/nginx/error.log
```
:::

## Paso 1 · 502 — nginx no conecta con la app

**Pregúntate:** ¿la app escucha donde nginx cree? El log lo dice.

:::pista Cómo comprobarlo
```
connect() failed (111: Connection refused) ... upstream: "http://127.0.0.1:8000/"
```
```bash
sudo ss -ltnp | grep gestion     # 127.0.0.1:8001  (la app se movió al 8001)
cat /etc/gestion/gestion.env     # PORT=8001
```
No cambies el puerto de la app (el 8001 es intencionado): corrige el `upstream`.
```bash
sudo sed -i 's/server 127.0.0.1:8000;/server 127.0.0.1:8001;/' /etc/nginx/sites-available/gestion
```
:::

## Paso 2 · 403 — nginx no puede leer el fichero

**Pregúntate:** nginx sirve como `www-data`. ¿Puede **entrar** en cada
directorio de la ruta y **leer** el fichero?

:::pista Cómo verlo y arreglarlo
```
open() ".../static/logo.txt" failed (13: Permission denied)
```
```bash
namei -l /srv/gestion/static/logo.txt
# drwx------ root root static   <- www-data no puede ni entrar
```
Hace falta `x` en los directorios y `r` en el fichero. **No** 777:
```bash
sudo chmod 0755 /srv/gestion/static
sudo chmod 0644 /srv/gestion/static/*
```
Para que no se rompa en el próximo deploy, el pipeline debe fijar permisos
(`install -m 0644`, `rsync --chmod=D755,F644`), no depender del `umask`.
:::

## Paso 3 · 504 — nginx se cansó de esperar

**Pregúntate:** ¿cuánto espera nginx y cuánto tarda el informe? Y sube el
timeout **sólo** en esa ruta.

:::pista Cómo hacerlo
```
upstream timed out (110: Connection timed out) while reading response header
```
`proxy_read_timeout 5s` y el informe tarda ~12 s. En el bloque del informe:
```nginx
location /api/informe {
    proxy_pass http://gestion_app;
    proxy_set_header Host $host;
    proxy_read_timeout 30s;
}
```
Si subieras el timeout de `location /`, cada petición colgada retendría un
worker 30 s y se agotarían: el sitio entero se cae despacio en vez de fallar
rápido.
:::

## Paso 4 · Aplica y verifica

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -s http://127.0.0.1/
curl -s http://127.0.0.1/static/logo.txt
time curl -s http://127.0.0.1/api/informe      # ~12 s, 200
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

| Código | Quién falla | Dónde mirar |
|---|---|---|
| 502 | nginx no conecta con el upstream (puerto mal, crash) | `error.log`, `ss -ltnp` |
| 503 | upstream sin servidores / app sobrecargada | `error.log`, la app |
| 504 | conecta pero tarda más que `proxy_read_timeout` | `error.log`, latencia |
| 403 | nginx no puede leer (permisos, `deny`, sin index) | `error.log`, `namei -l` |

- Un cambio de puerto en la app es cambio también en el proxy, el firewall y la
  monitorización. Revisa los changelogs.
- Timeouts largos sólo donde hacen falta; mejor aún, informe pesado **asíncrono**.

## Si te atascas

- Sigue 502 → ¿`ss -ltnp` confirma el puerto real? ¿recargaste nginx?
- Sigue 403 → `namei -l` y mira qué directorio de la ruta no tiene `x`.
- 504 en todo el sitio → subiste el timeout en `location /` en vez de sólo en
  `/api/informe`.
