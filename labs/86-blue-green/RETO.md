# Cutover blue-green

> Pipeline / runtime · blue-green · nginx reload · SEV2

## Escenario

En `shop-cutover` hay dos stacks vivos:

- **green** (`shop-green`, `:8081`) — 1.0.0, vulnerable (`GET /vuln` abierto). Es
  el único backend en el upstream de nginx.
- **blue** (`shop-blue`, `:8082`) — 1.2.0 parcheado, con health ok, **sin tráfico**.

Lee `~/ticket/INC-8602.txt`. El cutover es cambiar el upstream y recargar nginx.
Green no se apaga: es el rollback.

## Objetivos

1. El balanceador (`http://127.0.0.1/version`) sólo responde **1.2.0 blue**.
2. `GET /vuln` a través del LB ya no es 200.
3. **green sigue activo** en `:8081` (sigue en 1.0.0; no lo borres).
4. El PID maestro de nginx no cambia (`reload`, no `restart`).
5. En la config activa, el upstream **no** incluye `:8081`.

## Comandos que te pueden servir

```bash
curl -s http://127.0.0.1/version
curl -s http://127.0.0.1:8081/version ; curl -s http://127.0.0.1:8082/health
sudo cat /etc/nginx/sites-available/shop
sudo nginx -t && sudo systemctl reload nginx
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
