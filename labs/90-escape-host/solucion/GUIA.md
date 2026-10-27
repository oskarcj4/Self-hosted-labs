# Resolución guiada · Lab 90

:::piensa
Cinco palancas, un solo dato que la app necesita: `/data/msg`. Si un flag no
sirve para leer ese fichero, fuera.
:::

## Paso 1 · Lista montajes y modos

```bash
cd ~/edge && docker inspect edge-api-1 --format '{{json .Mounts}} {{.HostConfig.PidMode}} {{.HostConfig.NetworkMode}}'
```

## Paso 2 · compose.yaml mínimo

Quita `privileged`, `pid`, `network_mode`, el sock y `/:/host`.
Deja `./data:/data:ro` y `ports: ["8080:8080"]`.

```bash
docker compose up -d
curl -s localhost:8080
bash /opt/lab/check.sh
```
