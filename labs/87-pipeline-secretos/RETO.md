# Pipeline CI que filtra secretos

> Pipeline / runtime · CI · secretos · docker.sock

## Escenario

En `~/shop-ci` hay un pipeline casero (`pipeline.yml` + `./run-ci.sh`). La última
ejecución (un **pull_request**) dejó el token de despliegue en `logs/last-run.log`
y el job de build monta **docker.sock**: el runner puede crear contenedores
privilegiados en este host.

El deploy **sí** necesita `DEPLOY_TOKEN`, pero no en el YAML ni en el log.

## Objetivos

1. `pipeline.yml` no contiene el token ni dispara `pull_request`.
2. Los jobs no montan `docker.sock` ni imprimen el token.
3. El token vive en `secrets/deploy_token` (modo 600 o 400), no en git-yaml.
4. `./run-ci.sh` termina 0, genera `dist/shop.txt` y `dist/deployed.txt`, y el
   log nuevo **no** incluye `tclab-live-token`.

## Comandos que te pueden servir

```bash
cd ~/shop-ci
cat pipeline.yml jobs/build.sh logs/last-run.log
./run-ci.sh
ls -l secrets
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
