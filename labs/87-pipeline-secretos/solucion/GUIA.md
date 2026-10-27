# Resolución guiada · Lab 87

:::piensa
El runner ya sabe leer `secrets/deploy_token`. No hace falta inventar otra vía:
quita el token del YAML, deja de imprimirlo y deja de montar el socket.
:::

## Paso 1 · Mira el último log

```bash
cd ~/shop-ci && cat logs/last-run.log
```

## Paso 2 · Secreto en fichero

```bash
mkdir -p secrets
echo 'DEPLOY_TOKEN=tclab-live-token-do-not-commit' > secrets/deploy_token
chmod 600 secrets/deploy_token
```

## Paso 3 · pipeline.yml

`on: [push]` únicamente. Borra el bloque `env:`.

## Paso 4 · jobs/build.sh

Deja el `mkdir`/`echo shop-ok`. Quita el `echo token=` y el `docker run ... sock`.

```bash
./run-ci.sh
bash /opt/lab/check.sh
```
