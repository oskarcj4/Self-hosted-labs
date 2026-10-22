# Lab 83 — Reverse proxy con rate limiting (nginx)

## Escenario (hardening)

`web-83` sirve con **nginx como reverse proxy** delante de Apache (el backend,
en `127.0.0.1:8080`). Es la arquitectura correcta —nginx aguanta mucha
concurrencia y protege al backend—, pero **no tiene límite de peticiones**: una
ráfaga pasa íntegra al backend y lo tumba. Pon un **rate limit** por IP.

> **Sobre Cloudflare gratis:** Cloudflare es una CDN/WAF *alojada*, no corre
> dentro de un contenedor. En producción apuntas tu DNS a Cloudflare y su borde
> absorbe el DDoS antes de llegar a ti. Este lab monta el **equivalente que sí
> controlas en local**: un reverse proxy (nginx) con rate limiting. El concepto
> —un borde que filtra antes del origen— es el mismo. El curso 14 explica cuándo
> hace falta una CDN de verdad.

## Objetivos

1. Define una **zona de rate limit** por IP: `limit_req_zone` en el contexto
   `http` (p.ej. `rate=10r/s`).
2. **Aplica el límite** en la `location` con `limit_req zone=... burst=... nodelay`.
3. Mantén el `proxy_pass` al backend `127.0.0.1:8080`.
4. Deja la config **válida** (`nginx -t`) y el sitio sirviendo 200.

## Comandos que te pueden servir

```bash
sudoedit /etc/nginx/nginx.conf                  # limit_req_zone va en http { }
sudoedit /etc/nginx/sites-enabled/default       # limit_req va en location { }
sudo nginx -t
sudo service nginx reload

# simular la ráfaga (tu lab, inofensivo): sin límite casi todo 200; con límite, 503/429
ab -n 500 -c 50 http://127.0.0.1/
```

Ejemplo:

```nginx
# en http { } (nginx.conf):
limit_req_zone $binary_remote_addr zone=web:10m rate=10r/s;
limit_req_status 429;

# en location / { } (sites-enabled/default):
limit_req zone=web burst=20 nodelay;
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
