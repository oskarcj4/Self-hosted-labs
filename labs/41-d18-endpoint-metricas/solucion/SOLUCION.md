# Solución — Día 18: Dejar de publicar un endpoint de métricas

## 1. Ver el problema

```bash
cd ~/shop
docker compose ps        # shop: 0.0.0.0:8080->8080, 0.0.0.0:9100->9100
curl -s http://localhost:9100/metrics
# shop_build_info{...,db_host="pg-prod-01.interno",admin_path="/gestion-x7"} ...
```

## 2. ¿Lo necesita el scraper?

No. Los servicios de un mismo proyecto Compose comparten la red `shop_default`
y se encuentran por nombre: el scraper llega a `shop:9100` **sin** que el
puerto esté publicado. `ports:` sólo sirve para que entre tráfico **desde fuera
del host Docker**.

## 3. Quitar la publicación

```yaml
  shop:
    ...
    ports:
      - "8080:8080"   # web pública
    expose:
      - "9100"        # (opcional) documenta el puerto interno; no publica nada
```

```bash
docker compose up -d     # recrea 'shop' sin el puerto
```

## 4. Verificar

```bash
docker compose ps                                        # sólo 8080
curl -s --max-time 2 http://localhost:9100/metrics || echo cerrado
docker compose exec scraper wget -qO- http://shop:9100/metrics | head -2
sleep 6; docker compose exec scraper cat /tmp/last-scrape   # ok ...
```

## Lecciones

- Publicar (`ports:`) = abrir al exterior. Comunicación entre servicios = red interna, por nombre.
- Los endpoints de métricas, health detallado y debug filtran información útil
  para un atacante: versiones, hosts internos, rutas de administración.
- `expose:` es documentación; no abre nada en el host.
