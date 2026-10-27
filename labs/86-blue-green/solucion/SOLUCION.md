# Solución — Cutover blue-green

## 1. Comprueba los dos colores

```bash
curl -s http://127.0.0.1/version          # 1.0.0 green
curl -s http://127.0.0.1:8082/health      # ok 1.2.0 blue
sudo nginx -T | sed -n '/upstream shop/,/}/p'
```

Blue ya está sano. Falta que nginx le mande el tráfico.

## 2. Cambia el upstream y recarga

En `/etc/nginx/sites-available/shop`, deja **sólo** `127.0.0.1:8082`.
Comenta o borra `:8081`. Luego:

```bash
sudo nginx -t && sudo systemctl reload nginx
curl -s http://127.0.0.1/version          # 1.2.0 blue
systemctl is-active shop-green            # active
```

## Lecciones

- Blue-green: dos entornos completos. El corte es un puntero (upstream, DNS, VIP).
- Recargar el proxy cambia el puntero; reiniciarlo corta.
- No apagues green en el cutover: el rollback es volver a apuntar.
