# Solución — Día 21: Configuración montada en sólo lectura

## 1. El problema

```bash
cd ~/edge
docker inspect edge-gateway-1 --format '{{json .Mounts}}' | jq '.[0].RW'   # true
docker compose exec gateway sh -c 'echo "/ http://evil:80" >> /etc/gateway/routes.conf'
# ...y el cambio aparece en ~/edge/config/routes.conf del host
```

(Si lo probaste, deshazlo antes de seguir: `git`/copia, o borra la línea añadida.)

## 2. Primer intento: sólo `:ro`

```yaml
    volumes:
      - ./config:/etc/gateway:ro
```

```bash
docker compose up -d
docker compose logs gateway --tail 5
# OSError: [Errno 30] Read-only file system: '/etc/gateway/.runtime-cache'
```

La app escribe su caché junto a la configuración. El `README.md` dice que esa
ruta se puede cambiar con `GATEWAY_CACHE_DIR`.

## 3. Solución completa

```yaml
services:
  gateway:
    image: edge/gateway:3.1
    build: ./gateway
    ports:
      - "8080:8080"
    environment:
      GATEWAY_CACHE_DIR: /var/cache/gateway
    volumes:
      - ./config:/etc/gateway:ro
    tmpfs:
      - /var/cache/gateway
    restart: unless-stopped
```

```bash
docker compose up -d
curl -s localhost:8080/health      # gateway ok: 3 rutas, cache en /var/cache/gateway
docker compose exec gateway touch /etc/gateway/x   # Read-only file system
```

## Lecciones

- Configuración y secretos montados: **`:ro` por defecto**. El contenedor los lee, no los escribe.
- Separa lo que la app escribe (caché, temporales) en `tmpfs` o un volumen propio.
- Siguiente nivel: `read_only: true` en el servicio (todo el sistema de
  ficheros del contenedor en sólo lectura) + `tmpfs` para lo imprescindible.
