# Solución — Cerrar vías de escape al host

## 1. Inventario

```bash
cd ~/edge
cat compose.yaml
docker inspect edge-api-1 --format '{{.HostConfig.Privileged}} {{.HostConfig.PidMode}} {{.HostConfig.NetworkMode}}'
docker inspect edge-api-1 --format '{{json .Mounts}}'
```

Cada flag es una vía distinta: kernel (`privileged`), procesos del host
(`pid: host`), su red, su daemon Docker, su disco.

## 2. Lo que la app usa de verdad

Lee `/data/msg`. Eso es `./data:/data:ro`. El resto sobra.

Al quitar `network_mode: host` hace falta publicar el puerto:

```yaml
services:
  api:
    image: shop/edge:1.0
    build: ./api
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data:ro
    restart: unless-stopped
```

```bash
docker compose up -d
curl -s localhost:8080
```

## Lecciones

- `docker.sock` + `privileged` + `/` = escape al host, no “flexibilidad”.
- `pid: host` / `network_mode: host` rompen el aislamiento aunque no haya sock.
- Publica el puerto; no compartas la pila de red del host “porque es más fácil”.
