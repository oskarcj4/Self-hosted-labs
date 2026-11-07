# Resolución guiada · Lab 159

:::piensa Cada step es una puerta
El pipeline es una cadena de puertas: si una no se abre, lo de detrás no
ocurre. Lo barato y rápido va primero (pruebas, escaneo); lo que tiene efectos
(publicar, desplegar) va al final, y el despliegue debe saber deshacerse.
:::

## Paso 1 · El secreto

:::pista Qué hacer
```bash
cd ~/api && gitleaks dir . --no-banner     # encuentra el ghp_...
```
`config.py` → `GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")`. En la vida
real, además, **revocas** el token: ya está en el historial de git.
:::

## Paso 2 · test y scan

:::pista Cómo hacerlo
```yaml
  - name: test
    image: bash
    commands:
      - python3 -m unittest -v
  - name: scan
    image: bash
    commands:
      - gitleaks dir . --no-banner
```
:::

## Paso 3 · build y publish con etiqueta inmutable

:::pista Cómo hacerlo
`ci/build.sh "$CI_COMMIT_SHA"` que haga
`docker build -t localhost:5000/api:${1:0:12} .` y guarde el nombre en un
fichero (`.image`) para los steps siguientes; `publish`: `docker push "$(cat .image)"`.
:::

## Paso 4 · deploy con verificación y rollback

:::pista Cómo hacerlo
Antes de tocar nada, guarda la imagen actual:
`OLD=$(docker inspect -f '{{.Config.Image}}' api)`. Despliega la nueva, prueba
`/health` en bucle ~20 s; si no responde, relanza `OLD` y `exit 1`.
:::

## Cómo actuar en una situación así

- Una imagen = un commit. `latest` sólo como alias, nunca para desplegar.
- El rollback se prueba como cualquier otra función: rompe a propósito.
- Lo que el pipeline necesita entre steps (nombre de imagen) va en ficheros del workspace.

## Si te atascas

- El check dice "cambios sin commit": `ci-run` usa HEAD; haz commit.
- El step deploy no encuentra `.image`: los steps comparten el workspace, pero
  cada `commands` es un shell nuevo (las variables no sobreviven; los ficheros sí).
