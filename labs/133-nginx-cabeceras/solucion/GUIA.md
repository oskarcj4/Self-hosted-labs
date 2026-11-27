# Resolución guiada · Lab 133

:::piensa Tres problemas, tres sitios
En el mismo servidor hay tres fallos distintos: ficheros que nunca deberían
servirse (`.env`, `.git/`), cabeceras que el navegador necesita para
protegerse, y una cookie de sesión sin protección. Se arreglan en nginx, sin
tocar la aplicación, pero cada uno en un sitio distinto del bloque `server`.
:::

**El plan:** (1) ver qué se descarga, (2) bloquear los ficheros ocultos,
(3) añadir las cabeceras, (4) proteger la cookie y (5) comprobar.

## Paso 1 · ¿Qué se descarga que no debería?

:::pista Cómo hacerlo
```bash
curl -s http://tienda.lab/.env | head -3
curl -s http://tienda.lab/.git/config
curl -sI http://tienda.lab/
cat /etc/nginx/sites-available/tienda
```
`curl -I` pide sólo las cabeceras de la respuesta.

**Qué deberías ver:** credenciales en `.env`, la URL del repositorio en
`.git/config` (con `.git/` entero alguien reconstruye el código fuente), y en
las cabeceras `Server: nginx/1.22.1` sin ninguna cabecera de seguridad.
:::

## Paso 2 · Bloquea los ficheros ocultos

**Pregúntate:** ¿hay alguna ruta que empiece por punto que **sí** deba
servirse?

:::pista Cómo hacerlo
Sí: `/.well-known/`, que usan estándares como Let's Encrypt (ACME) o
`security.txt`. Dentro del bloque `server`:
```nginx
    location ^~ /.well-known/ {
        try_files $uri =404;
    }
    location ~ /\. {
        deny all;
    }
```
- `location ~ /\.` es una expresión regular: cualquier ruta con un segmento que
  empiece por punto (`/.env`, `/.git/config`). `\.` es un punto literal.
  `deny all` responde 403.
- `^~` hace que una `location` de prefijo gane a las expresiones regulares: si
  la ruta empieza por `/.well-known/`, nginx no llega a mirar la regla del
  punto.
:::

## Paso 3 · Cabeceras de seguridad

**Pregúntate:** `add_header` sólo se aplica a respuestas 2xx y 3xx. ¿Qué pasa
con un 404 o un 403?

:::pista Cómo hacerlo
Que se quedarían sin cabeceras. Con `always`, se añaden a todas. Al principio
del bloque `server`:
```nginx
    server_tokens off;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

| Cabecera | Qué le dice al navegador |
|---|---|
| `X-Frame-Options: DENY` | No mostrar esta web dentro de un `<iframe>` de otra (*clickjacking*). |
| `X-Content-Type-Options: nosniff` | Respetar el tipo de contenido declarado, sin "adivinar" (un `.txt` no se ejecuta como script). |
| `Content-Security-Policy` | `default-src 'self'`: cargar scripts, estilos e imágenes sólo de este mismo origen. `frame-ancestors 'none'`: la versión moderna de `X-Frame-Options`. |
| `Referrer-Policy` | Cuánto de la URL de origen se envía al seguir un enlace. |

`server_tokens off` quita la versión de la cabecera `Server`.

Ojo: si una `location` tiene **su propio** `add_header`, deja de heredar
todos los del `server`. Aquí ninguna lo tiene.
:::

## Paso 4 · La cookie de sesión

**Pregúntate:** la cookie la pone la aplicación. ¿Puedes añadirle protecciones
desde nginx?

:::pista Cómo hacerlo
Sí, con `proxy_cookie_flags`. En la `location /cuenta/` que ya existe:
```nginx
    location /cuenta/ {
        proxy_pass http://127.0.0.1:9133/;
        proxy_cookie_flags ~ httponly secure samesite=lax;
    }
```
`~` aplica los atributos a todas las cookies que lleguen de la aplicación.

| Atributo | Qué evita |
|---|---|
| `httponly` | Que JavaScript lea la cookie (un XSS no puede robarla). |
| `secure` | Que se envíe por HTTP sin cifrar. |
| `samesite=lax` | Que otra web la use en peticiones hacia aquí (CSRF). |
:::

## Paso 5 · Aplica y comprueba

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -s -o /dev/null -w '%{http_code}\n' http://tienda.lab/.env
curl -s -o /dev/null -w '%{http_code}\n' http://tienda.lab/.well-known/security.txt
curl -sI http://tienda.lab/no-existe
curl -sI http://tienda.lab/cuenta/login | grep -i set-cookie
bash /opt/lab/check.sh
```
**Qué deberías ver:** `403` en `.env`, `200` en `security.txt`, las cabeceras
también en el 404, `Server: nginx` sin versión y la cookie con
`HttpOnly; Secure; SameSite=Lax`.

## Cómo actuar en una situación así

- Nunca despliegues el directorio del repositorio como raíz web: construye un
  artefacto sin `.git` ni `.env`.
- Pon las cabeceras en un fichero aparte (`snippets/seguridad.conf`) e
  inclúyelo en cada `server`, para no olvidarlas.
- Comprueba con `curl -I` o con observatory.mozilla.org.

## Si te atascas

- **Las cabeceras no salen en `/cuenta/`:** esa `location` tiene su propio
  `add_header`; repítelas dentro o usa un `include`.
- **`/.well-known/` también da 403:** falta el `^~`, y gana la regla del punto.
- **`nginx -t`: `unknown directive "proxy_cookie_flags"`:** necesita nginx
  1.19.3 o superior (el de Debian 12 lo tiene).
