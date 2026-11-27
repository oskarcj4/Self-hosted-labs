# Resolución guiada · Lab 87

:::piensa Quién recibe el secreto, y dónde acaba
Un pipeline de CI ejecuta código del repositorio con los secretos de
producción a mano. Tres fugas típicas, y este pipeline tiene las tres: el
secreto **escrito en el YAML** (está en el repo), el secreto **impreso en el
log** (lo lee cualquiera con acceso a los logs) y el secreto disponible en
**pull requests** (cualquiera que abra un PR, incluso desde un fork, ejecuta
su código con él). Además, montar `docker.sock` en un job le da control total
del motor Docker del runner.
:::

**El plan:** (1) entender cómo funciona el runner, (2) sacar el token a un
fichero, (3) limpiar `pipeline.yml`, (4) limpiar `jobs/build.sh` y (5)
ejecutar y comprobar el log.

## Paso 1 · ¿Cómo funciona este runner?

**Objetivo:** saber de dónde saca el token, para no tener que inventar otra vía.

:::pista Cómo hacerlo
```bash
cd ~/shop-ci
cat logs/last-run.log
cat run-ci.sh
```
**Qué deberías ver:** `token=tclab-live-token-…` en el log. Y en
`run-ci.sh`, dos fuentes del token:

- El bloque `env:` de `pipeline.yml`, que exporta como variables.
- Si existe `secrets/deploy_token`, lo carga con `. secrets/deploy_token`
  entre `set -a` y `set +a`. `.` (o `source`) ejecuta el fichero en la shell
  actual, y `set -a` hace que toda variable que se defina se **exporte** a los
  procesos hijos (los jobs). El fichero, por tanto, tiene formato de shell:
  `NOMBRE=valor`.
:::

## Paso 2 · El secreto, en un fichero protegido

:::pista Cómo hacerlo
```bash
install -d -m 0700 secrets
install -m 0600 /dev/null secrets/deploy_token
echo 'DEPLOY_TOKEN=tclab-live-token-do-not-commit' > secrets/deploy_token
ls -l secrets/
```
`install -m 0600 /dev/null` crea el fichero vacío ya con permisos `600`;
después lo rellenas. En ningún momento ha sido legible por otros.

**Qué deberías ver:** `-rw-------`.
:::

## Paso 3 · `pipeline.yml` sin secreto y sin `pull_request`

**Pregúntate:** ¿por qué un PR no debería recibir el token de producción?

:::pista Cómo hacerlo
Porque el código de un PR lo escribe quien abre el PR, no tu equipo: si el
pipeline le da el token, cualquiera puede escribir un job que lo envíe fuera.
Deja `pipeline.yml` así:
```yaml
name: shop-deploy
on: [push]
jobs:
  build:
    run: bash jobs/build.sh
  deploy:
    run: bash jobs/deploy.sh
```
Sin bloque `env:` (el token ya llega del fichero) y sólo con `push`.
:::

## Paso 4 · `jobs/build.sh` sin fugas

:::pista Cómo hacerlo
```bash
nano jobs/build.sh
```
Quita la línea `echo "token=…"` y el `docker run … -v /var/run/docker.sock…`.
Queda:
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "building shop"
mkdir -p dist
echo shop-ok > dist/shop.txt
```
`docker.sock` es la puerta de control del motor Docker. Quien lo tiene puede
crear un contenedor privilegiado que monte el disco del host: es root de la
máquina. Un job de build no lo necesita.
:::

## Paso 5 · Ejecuta y comprueba

```bash
./run-ci.sh; echo "exit=$?"
ls dist/
grep -c tclab-live-token logs/last-run.log
bash /opt/lab/check.sh
```
**Qué deberías ver:** `event=push`, `exit=0`, `shop.txt` y `deployed.txt` en
`dist/` (el deploy encontró el token) y `0` coincidencias del token en el log
nuevo, que ha sustituido al viejo.

## Cómo actuar en una situación así

- **Secretos fuera del repo:** en una CI real, en su gestor de secretos
  (GitHub/Gitea Secrets, Vault), nunca en el YAML.
- **Nunca imprimas un secreto**, ni "para depurar". Las CI reales lo
  enmascaran en los logs, pero sólo si saben que es un secreto.
- **Sin secretos en `pull_request`** de forks.
- **Nada de `docker.sock`** en jobs: para construir imágenes, herramientas sin
  demonio (buildah, kaniko).
- El token salió en un log: en un caso real, **rótalo**.

## Si te atascas

- **`falta DEPLOY_TOKEN`:** el fichero no tiene el formato `DEPLOY_TOKEN=valor`
  o no está en `secrets/deploy_token`.
- **El log sigue mostrando el token:** queda algún `echo` en `build.sh` o en
  `deploy.sh`. `grep -rn DEPLOY_TOKEN jobs/`.
- **El check dice que `pipeline.yml` aún dispara `pull_request`:** también
  cuenta si la palabra aparece en un comentario. Bórralo.
