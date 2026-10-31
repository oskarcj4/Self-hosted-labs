# Hardening de nginx: ficheros ocultos, cabeceras y cookies

> Hardening web · nginx · curl -I · CSP · cookies

## Escenario

Un pentest sobre `http://tienda.lab` ha dejado tres hallazgos
(`~/ticket/SEC-133.txt`): se pueden descargar `/.env` y `/.git/config`
(con credenciales dentro), faltan las cabeceras de seguridad y la cookie de
sesión viaja sin protección. Arréglalo en nginx, sin tocar la aplicación.

| Medida | Qué evita |
|---|---|
| Bloquear `/.env`, `/.git/` | robo de credenciales y del código fuente |
| `X-Frame-Options` / CSP `frame-ancestors` | que te metan en un iframe (clickjacking) |
| `Content-Security-Policy` | que se cargue JavaScript de donde no debe (XSS) |
| `X-Content-Type-Options: nosniff` | que el navegador "adivine" tipos y ejecute lo que no es |
| Cookie `HttpOnly` | que JavaScript lea la cookie de sesión |
| Cookie `Secure` | que viaje por HTTP sin cifrar |
| Cookie `SameSite` | que otra web la use en peticiones (CSRF) |

## Objetivos

1. Que `/.env`, `/.env.bak` y todo `/.git/` den 403 o 404, sin romper
   `/.well-known/security.txt`, la web ni `/static/`.
2. Añade `X-Frame-Options`, `Content-Security-Policy` y
   `X-Content-Type-Options` a **todas** las respuestas, también a los 404.
3. Que la cookie de `/cuenta/login` salga con `HttpOnly`, `Secure` y
   `SameSite`. Pista: `proxy_cookie_flags`.
4. Bonus que también se comprueba: que la cabecera `Server` no diga la
   versión de nginx.

## Comandos que te pueden servir

```bash
curl -I http://tienda.lab/
curl -s http://tienda.lab/.env
curl -sI http://tienda.lab/no-existe
curl -sI http://tienda.lab/cuenta/login | grep -i set-cookie
sudo nano /etc/nginx/sites-available/tienda
sudo nginx -t && sudo systemctl reload nginx
```

> `add_header` sin `always` sólo se aplica a respuestas 2xx/3xx. Y si un
> `location` tiene su propio `add_header`, deja de heredar los del `server`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
