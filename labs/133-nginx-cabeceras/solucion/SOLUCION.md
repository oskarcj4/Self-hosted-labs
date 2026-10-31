# Solución — nginx: ficheros ocultos, cabeceras y cookies

## Qué pasaba

- `/.env` y `/.git/` se servían: secretos y código fuente descargables.
- Sin `X-Frame-Options`, CSP, `nosniff` ni `Referrer-Policy`; `Server` con versión.
- La cookie de sesión de `/cuenta/` sin `HttpOnly`, `Secure` ni `SameSite`.

## Arreglo

`/etc/nginx/sites-available/tienda`:

```nginx
server {
    listen 80 default_server;
    server_name tienda.lab;
    root /var/www/tienda;
    index index.html;
    server_tokens off;

    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location ^~ /.well-known/ { try_files $uri =404; }
    location ~ /\. { deny all; }

    location / { try_files $uri $uri/ =404; }

    location /cuenta/ {
        proxy_pass http://127.0.0.1:9133/;
        proxy_cookie_flags ~ httponly secure samesite=lax;
    }
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://tienda.lab/
curl -sI http://tienda.lab/cuenta/login | grep -i set-cookie
bash /opt/lab/check.sh
```

## Más allá del lab

- Los secretos de `.env` estuvieron expuestos: rótalos.
- Con HTTPS, añade `Strict-Transport-Security`.
- Empieza la CSP en modo `Content-Security-Policy-Report-Only` en apps grandes.
