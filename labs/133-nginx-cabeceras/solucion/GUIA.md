# Resolución guiada · Lab 133

:::piensa Antes de tocar nada
Tres problemas distintos en el mismo servidor: ficheros que no deberían
servirse, cabeceras que el navegador necesita para protegerse y una cookie de
sesión sin protección. Cada uno se arregla en un sitio distinto del `server`.
:::

## Paso 1 · ¿Qué se descarga que no debería?

:::pista Cómo comprobarlo
```bash
curl -s http://tienda.lab/.env | head -3
curl -s http://tienda.lab/.git/config
```
:::

## Paso 2 · Bloquea los ficheros ocultos

**Pregúntate:** ¿qué ruta oculta sí debe servirse? (`/.well-known/` para ACME y otros estándares.)

:::pista Cómo hacerlo
```nginx
location ^~ /.well-known/ { try_files $uri =404; }
location ~ /\. { deny all; }
```
`^~` hace que esa ruta gane a la regex.
:::

## Paso 3 · Cabeceras de seguridad

**Pregúntate:** `add_header` sólo se aplica a respuestas 2xx/3xx. ¿Y en un 404 o 403?

:::pista Cómo hacerlo
```nginx
server_tokens off;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```
Cuidado: si un `location` tiene su propio `add_header`, deja de heredar los del `server`.
:::

## Paso 4 · La cookie

**Pregúntate:** la cookie la pone el backend. ¿Puedes añadirle flags desde nginx sin tocar la app?

:::pista Cómo hacerlo
```nginx
location /cuenta/ {
    proxy_pass http://127.0.0.1:9133/;
    proxy_cookie_flags ~ httponly secure samesite=lax;
}
```
```bash
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://tienda.lab/ ; curl -sI http://tienda.lab/cuenta/login | grep -i set-cookie
```
:::

## Cómo actuar en una situación así

- **Nunca despliegues el directorio del repo como raíz web**: construye un artefacto sin `.git` ni `.env`.
- Cabeceras con `always` y en un único sitio (snippet incluido en cada `server`).
- Comprueba con `curl -I` o con observatory.mozilla.org.

## Si te atascas

- Las cabeceras no salen en `/cuenta/`: ese `location` define otro `add_header`; repítelas o usa un `include`.
- `proxy_cookie_flags` da error: necesita nginx ≥ 1.19.3 (Debian 12 lo tiene).
