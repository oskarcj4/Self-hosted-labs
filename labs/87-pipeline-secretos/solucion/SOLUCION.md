# Solución — Pipeline CI que filtra secretos

## 1. El daño ya está en el log

```bash
cd ~/shop-ci
grep -n token logs/last-run.log pipeline.yml jobs/build.sh
```

Tres problemas distintos: secreto en el manifiesto, eco en el job, socket de
Docker (equivale a root en este host) y `pull_request` con secretos.

## 2. Token fuera del YAML

```bash
mkdir -p secrets
printf 'DEPLOY_TOKEN=tclab-live-token-do-not-commit\n' > secrets/deploy_token
chmod 600 secrets/deploy_token
```

En `pipeline.yml`: `on: [push]` y **sin** bloque `env:`.

## 3. Job de build tonto

`jobs/build.sh` sólo construye el artefacto: nada de `echo "$DEPLOY_TOKEN"` ni
`docker.sock`. `run-ci.sh` ya carga `secrets/deploy_token` para el deploy.

```bash
./run-ci.sh
grep -i token logs/last-run.log || echo "limpio"
```

## Lecciones

- Un PR de un fork no debe heredar secretos de producción.
- `echo $SECRET` acaba en logs, tickets y copies de CI.
- El socket de Docker en un job = el job es root del host.
