# Capabilities y no-new-privileges

> Pipeline / runtime · Docker · capabilities · least privilege

## Escenario

`api` (stack `caps`, en `~/caps`) es un HTTP en `:8080`. En `compose.yaml` alguien
le puso `cap_add: [ALL, SYS_ADMIN]` “por si había que tunear la red”. No lo
necesita: es Python escuchando en 8080.

Con `CAP_SYS_ADMIN` un proceso puede montar, pivotar namespaces y acercarse a
un escape. Hay que dejarla en **mínimo privilegio**.

## Objetivos

1. El contenedor **no** es `privileged` y **no** tiene `SYS_ADMIN`/`ALL` en CapAdd.
2. Tiene `cap_drop: ALL` (runtime y `compose.yaml`).
3. `security_opt` incluye `no-new-privileges`.
4. `curl -s http://127.0.0.1:8080/` sigue respondiendo `api ok`.

## Comandos que te pueden servir

```bash
cd ~/caps && cat compose.yaml
docker inspect caps-api-1 --format '{{.HostConfig.CapAdd}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}}'
docker compose up -d
curl -s localhost:8080
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
