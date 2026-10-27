# Scan IaC del Compose

> Pipeline / runtime · IaC · scanner · falsos negativos

## Escenario

En `~/iac` hay un escáner estilo Checkov (`./scan.sh`) y el PR #301 dejó el
`compose.yaml` **en verde**:

```bash
cd ~/iac && ./scan.sh      # scan: limpio
```

Mira el contenedor que está corriendo. Ahora mira el YAML. El PR no arregló
nada: aprendió a esquivar el `grep`. El escáner tiene **falsos negativos**
(no ve lo que hay) y **falsos positivos** (ve lo que no hay, como texto en un
comentario).

Un escáner sin tests es una opinión. `./test-scan.sh` pasa `scan.sh` por
`tests/deny/` (deben fallar) y `tests/allow/` (deben pasar). Hoy falla.

## Reglas HIGH que scan.sh tiene que aplicar a cada servicio

- Imagen sin tag fijo: `:latest` **o sin tag** (sin tag = `latest`). Cuidado
  con `registro:5000/app`: ese `:` es un puerto, no un tag. Un digest
  `@sha256:…` cuenta como fijado.
- Corre como root: sin `user:`, o `user` es `root`/`0` (con o sin `:grupo`).
- `privileged` verdadero (también si llega por `${VAR:-true}`).
- Monta `docker.sock` (sintaxis corta o larga).
- Fail-closed: si el YAML no se puede evaluar, el scan **no** es limpio.

## Objetivos

1. `scan.sh` aplica las reglas y supera el corpus oculto del check (más
   casos que los de `tests/`). `./test-scan.sh` en verde.
2. `compose.yaml` arreglado de verdad: `./scan.sh` limpio.
3. El contenedor `api` corre sin privileged, con usuario no root, desde una
   imagen con tag fijo, y `curl :8080` → `api ok`.

## Comandos que te pueden servir

```bash
cd ~/iac
docker inspect -f '{{.Config.Image}} user={{.Config.User}} priv={{.HostConfig.Privileged}}' \
  $(docker compose ps -q api)
docker compose -f compose.yaml config --format json | jq '.services.api'
./test-scan.sh
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
