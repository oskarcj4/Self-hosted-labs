# Resolución guiada · Lab 86

:::piensa
No tienes que parchear green. Blue ya está en 1.2.0. El trabajo es de tráfico,
no de ficheros de la app.
:::

## Paso 1 · Health de blue

```bash
curl -s http://127.0.0.1:8082/version
```

## Paso 2 · Edita el upstream

`sudo nano /etc/nginx/sites-available/shop` — una sola línea `server 127.0.0.1:8082;`
dentro de `upstream shop`.

## Paso 3 · Recarga

```bash
sudo nginx -t && sudo systemctl reload nginx
```

:::ojo
`systemctl stop shop-green` hace fallar el lab: green es el plan B.
:::

```bash
bash /opt/lab/check.sh
```
