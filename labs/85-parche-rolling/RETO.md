# Parche rolling sin downtime

> Pipeline / runtime · rolling update · nginx · SEV2

## Escenario

`shop-lb` sirve la tienda en `http://127.0.0.1/` con **dos backends**
(`shop-a` en `:8081`, `shop-b` en `:8082`), ambos en **1.0.0**. Esa versión
expone `GET /vuln` → `CVE-2024-SHOP open`. El parche **1.2.0** ya está en
`/opt/shop/releases/1.2.0`. Lee `~/ticket/INC-8501.txt`.

Si tiras nginx o dejas un backend muerto, hay corte. El procedimiento es
rolling: un backend, comprobar, el otro. Recargar nginx si hace falta;
**no** `systemctl restart nginx`.

## Objetivos

1. `curl -s http://127.0.0.1/version` (varias veces) sólo ve **1.2.0**.
2. `shop-a` y `shop-b` están activos y cada uno responde **1.2.0**.
3. `GET /vuln` a través del balanceador ya no es 200.
4. El **PID maestro de nginx** es el mismo que al plantar el lab.

## Comandos que te pueden servir

```bash
systemctl status nginx shop-a shop-b
curl -sI http://127.0.0.1/version
curl -s http://127.0.0.1:8081/version ; curl -s http://127.0.0.1:8082/version
ls /opt/shop/releases /srv/app-a /srv/app-b
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-a/ && sudo systemctl restart shop-a
sudo systemctl reload nginx     # si tocas la config; no uses restart
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
