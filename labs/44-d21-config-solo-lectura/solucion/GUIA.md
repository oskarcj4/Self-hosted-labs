# Resolución guiada · Día 21

:::piensa Antes de tocar nada
Un contenedor debería **leer** su configuración, no escribirla. Montarla en lectura/escritura convierte un compromiso del contenedor en un cambio persistente en el host. El enunciado ya te avisa de la segunda parte: al poner `:ro` algo se rompe. Cuando algo se rompe al endurecer, **lee los logs**: te dicen qué necesita la app.
:::

## Paso 1 · Comprueba el riesgo

**Pregúntate:** ¿el montaje es de escritura? ¿Un cambio desde dentro aparece en el host?

:::pista Cómo comprobarlo
```bash
cd ~/edge
docker inspect edge-gateway-1 --format '{{json .Mounts}}'
```
Busca `"RW":true`. No hace falta escribir nada para comprobarlo; si lo pruebas, deshaz el cambio en `config/routes.conf`.
:::

## Paso 2 · Primer intento: sólo `:ro`

:::pista Cómo hacerlo
```yaml
    volumes:
      - ./config:/etc/gateway:ro
```
```bash
docker compose up -d
docker compose ps -a
docker compose logs gateway --tail 20
```
:::

## Paso 3 · Lee por qué falla

**Pregúntate:** ¿qué intenta escribir la app y dónde? El error lo dice. ¿Hay forma de mover esa escritura a otro sitio?

:::pista Dónde mirar
```bash
cat README.md
```
La app escribe una caché junto a la configuración, y el README explica una variable de entorno para cambiar esa ruta.
:::

## Paso 4 · Separa lo que se lee de lo que se escribe

**Pregúntate:** ¿dónde pongo la caché? Necesita ser escribible pero no persistente: `tmpfs` (memoria) es perfecto.

:::pista Cómo hacerlo
```yaml
    environment:
      GATEWAY_CACHE_DIR: /var/cache/gateway
    volumes:
      - ./config:/etc/gateway:ro
    tmpfs:
      - /var/cache/gateway
```
```bash
docker compose up -d
curl -s localhost:8080/health
docker compose exec gateway touch /etc/gateway/x    # debe fallar: Read-only
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Configuración y secretos montados: `:ro` por defecto.**
- **Cuando el endurecimiento rompe algo, lee el log** y separa lo que la app escribe (caché, temporales) en `tmpfs` o un volumen propio.
- Siguiente nivel: `read_only: true` para todo el sistema de ficheros del contenedor, con `tmpfs` para lo imprescindible.

## Si te atascas

- El contenedor se reinicia en bucle: `docker compose logs gateway` te dice la ruta exacta.
