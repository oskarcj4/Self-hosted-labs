# Resolución guiada · Lab 91

:::piensa
El `grep` lee el **texto** del YAML. Docker ejecuta el resultado de
interpolar variables, expandir `extends` y normalizar volúmenes. Una política
que no mira lo mismo que Docker siempre tendrá un bypass.
:::

## Paso 1 · Mira lo que Docker ve

```bash
docker compose -f fixtures/bypass-interp.yaml config
docker compose -f fixtures/bypass-longform.yaml config --format json | jq '.services.x'
```

`privileged: ${PRIV:-true}` sale como `"privileged": true`. Los volúmenes
cortos y largos salen igual: `{type: bind, source: ..., target: ...}`.

## Paso 2 · Política con jq sobre el JSON

Recorre `.services | to_entries[]` y emite una línea por cada violación:
privileged, `pid/ipc/network_mode/userns_mode == "host"`, binds peligrosos
(`/`, `/var/run`, `/run`, `/proc`, `/sys`, `/etc`, `/var/lib/docker`,
`*docker.sock`), `cap_add` peligrosas (ojo con el prefijo `CAP_`) y
`unconfined` en `security_opt`. Si hay alguna línea, `exit 1`.

## Paso 3 · Fail-closed

Si `docker compose config` falla (YAML roto), la política **niega**. Un gate
que deja pasar lo que no entiende es un gate abierto.

## Paso 4 · Engancha y limpia

`./admit.sh compose.yaml` antes de `docker compose up` en `deploy.sh` (con
`set -e`, sin `|| true`). Quita privileged y el socket de `compose.yaml` y
despliega.
