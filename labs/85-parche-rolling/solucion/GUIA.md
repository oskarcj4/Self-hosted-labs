# Resolución guiada · Lab 85

:::piensa Antes de tocar nada
Hay dos copias de la app y un nginx delante. El corte aparece si matas nginx o
si dejas de servir en el 80. Parchear un backend no tumba el LB.
:::

## Paso 1 · Mira versiones y el PID de nginx

```bash
curl -s http://127.0.0.1:8081/version
curl -s http://127.0.0.1:8082/version
systemctl show -p MainPID --value nginx
cat /var/lib/tclab/nginx.pid
```

## Paso 2 · Copia 1.2.0 a app-a y reinicia sólo shop-a

```bash
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-a/
sudo systemctl restart shop-a
```

El balanceador sigue contestando: app-b sigue en 1.0.0.

## Paso 3 · Igual con app-b

```bash
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-b/
sudo systemctl restart shop-b
```

:::ojo No hagas restart de nginx
`systemctl restart nginx` cambia el PID maestro y el validador lo pilla.
:::

## Paso 4 · Verifica

```bash
curl -s http://127.0.0.1/vuln
bash /opt/lab/check.sh
```
