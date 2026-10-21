# Resolución guiada · Día 18

:::piensa Antes de tocar nada
Hay que distinguir dos cosas que se confunden mucho en Docker: **publicar** un puerto (`ports:`) abre una puerta desde fuera del host; **comunicarse entre servicios** del mismo proyecto no necesita publicar nada, porque comparten una red interna y se encuentran por nombre.
:::

## Paso 1 · ¿Qué expone el endpoint?

**Pregúntate:** ¿qué información regala `/metrics` a quien llegue al host?

:::pista Cómo comprobarlo
```bash
cd ~/shop
docker compose ps
curl -s http://localhost:9100/metrics | head
```
Versiones, hosts internos, rutas de administración: un mapa para un atacante.
:::

## Paso 2 · ¿Por qué se publicó?

**Pregúntate:** el scraper está en el mismo proyecto Compose. ¿Necesita que el puerto esté publicado en el host para llegar a `shop:9100`?

:::pista Cómo comprobarlo
```bash
docker compose exec scraper wget -qO- http://shop:9100/metrics | head -3
docker network ls | grep shop
```
Lo alcanza por la red interna del proyecto, usando el nombre del servicio. `ports:` no tiene nada que ver.
:::

## Paso 3 · Retira la publicación en el YAML

**Pregúntate:** ¿por qué en `compose.yaml` y no con un comando? Porque el próximo `docker compose up` volvería a aplicar lo que diga el YAML.

:::pista Cómo hacerlo
En el servicio `shop`, deja en `ports:` sólo la web. Si quieres documentar el puerto interno, usa `expose:` (no publica nada):
```yaml
    ports:
      - "8080:8080"
    expose:
      - "9100"
```
```bash
docker compose up -d
```
:::

## Paso 4 · Verifica los cuatro objetivos

```bash
docker compose ps                                       # sólo 8080
curl -s --max-time 2 http://localhost:9100/metrics || echo cerrado
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/
sleep 6; docker compose exec scraper cat /tmp/last-scrape
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Antes de publicar, pregunta: ¿quién de fuera necesita llegar?** Si la respuesta es "otro contenedor", no publiques.
- **Métricas, health detallado y debug** filtran información útil: nunca publicados.
- **El cambio va en el YAML**, no en el runtime.

## Si te atascas

- El scraper deja de funcionar: comprueba que no cambiaste la red o el nombre del servicio.
