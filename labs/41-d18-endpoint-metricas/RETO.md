# Día 18 — Dejar de publicar un endpoint de métricas

> 30 días de DevSecOps · Docker · Exposición del runtime de contenedores

## Escenario

El stack `shop` (en `~/shop`) tiene dos servicios: `shop` (la tienda) y
`scraper` (recoge métricas cada 5 s, como haría Prometheus). Alguien publicó
el puerto de métricas `9100` en el host "para que el scraper lo vea".

Mira lo que enseña: `curl http://localhost:9100/metrics` (versión, host de la
base de datos, ruta del panel de administración…).

## Objetivos

1. Ningún contenedor debe publicar el puerto `9100` en el host.
2. Desde el host, `:9100` ya no debe responder.
3. La web sigue publicada en `:8080`.
4. El `scraper` debe seguir leyendo `http://shop:9100/metrics` por la red interna.
5. El cambio debe estar en `compose.yaml` (que el próximo `up` no lo deshaga).

## Comandos que te pueden servir

```bash
cd ~/shop && cat compose.yaml
docker compose ps
docker port shop-shop-1
curl -s http://localhost:9100/metrics
docker compose exec scraper cat /tmp/last-scrape
docker compose exec scraper wget -qO- http://shop:9100/metrics | head -3
docker compose up -d          # aplica los cambios del compose.yaml
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
