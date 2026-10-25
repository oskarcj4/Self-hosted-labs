# Cerrar vías de escape al host

> Pipeline / runtime · Docker · container escape · compose

## Escenario

`api` (stack `edge`, `~/edge`) sólo tiene que leer `/data/msg` y servirlo en
`:8080`. El `compose.yaml` actual es un catálogo de escapes:

- `privileged: true`
- `pid: host` y `network_mode: host`
- `/var/run/docker.sock`
- `/:/host` (el filesystem del host)

Cualquiera que entre en ese contenedor es root del motor Docker de este lab
(y ve `/` del host). La función real no necesita nada de eso.

## Objetivos

1. Runtime **sin** privileged, **sin** pid/net host, **sin** docker.sock, **sin**
   montaje de `/` del host.
2. El cambio está en `compose.yaml` (no vale un `docker update` suelto).
3. Sigue montado `./data` y `curl -s http://127.0.0.1:8080/` devuelve `edge-ok`.

## Comandos que te pueden servir

```bash
cd ~/edge && cat compose.yaml
docker inspect edge-api-1 --format '{{.HostConfig.Privileged}} {{.HostConfig.PidMode}} {{.HostConfig.NetworkMode}} {{json .Mounts}}'
docker compose up -d
curl -s localhost:8080
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
