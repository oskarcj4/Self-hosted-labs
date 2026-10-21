# Solución — Servicio caído tras un reinicio

## 1. Diagnóstico: primero el error, luego el arreglo

```bash
systemctl status nginx          # inactive (dead), disabled
systemctl status shop-api       # inactive (dead), disabled
sudo nginx -t
```

`nginx -t` enseña el **primer** error que encuentra, con fichero y línea:

```
nginx: [emerg] invalid number of arguments in "proxy_pass" directive in /etc/nginx/sites-enabled/shop:13
```

En la línea 12 falta el `;` de `proxy_pass`, así que nginx lee la línea de
debajo como parte de la misma directiva.

Lo arreglas y vuelves a lanzar `nginx -t`. Ahora sale el segundo error:

```
nginx: [emerg] a duplicate default server for 0.0.0.0:80 in /etc/nginx/sites-enabled/shop.bak:2
```

`nginx.conf` incluye `sites-enabled/*`: **todos** los ficheros, también
`shop.bak`. La "copia de seguridad" define un segundo `default_server`.

## 2. Arreglo

```bash
sudo sed -i 's|proxy_pass http://127.0.0.1:8081$|proxy_pass http://127.0.0.1:8081;|' /etc/nginx/sites-available/shop
sudo mkdir -p /root/nginx-backups
sudo mv /etc/nginx/sites-enabled/shop.bak /root/nginx-backups/
sudo nginx -t                    # syntax is ok / test is successful
```

## 3. Arrancar y habilitar

```bash
sudo systemctl enable --now shop-api nginx
systemctl is-enabled nginx shop-api   # enabled / enabled
curl -s http://127.0.0.1/api/health   # shop-api ok
```

Arranca primero el backend y después el proxy. Si nginx arranca antes, los
primeros usuarios ven `502` (ver lab 62).

## Lecciones

- `active` y `enabled` son cosas distintas. `systemctl start` arregla el ahora;
  `enable` arregla el próximo arranque. `enable --now` hace las dos.
- `nginx -t` antes de cada `reload`. Un reload con la config rota falla sin
  tirar el servicio; un **reinicio** con la config rota lo deja caído.
- Nunca guardes copias en `sites-enabled/`, `conf.d/` ni en ningún directorio
  que se cargue con `*`. Guárdalas fuera, o mejor: usa git (`etckeeper`).
- Tras parchear y reiniciar, comprueba siempre los servicios críticos:
  `systemctl --failed` y una petición real.
