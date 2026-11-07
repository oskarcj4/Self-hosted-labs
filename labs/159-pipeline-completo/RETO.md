# Pipeline completo

> CI/CD · Woodpecker · pruebas · gitleaks · registro · etiqueta por commit · health check · rollback

## Escenario

El pipeline de la API (`~/api/.woodpecker.yaml`) hace sólo dos cosas:
`docker build -t api:latest` y desplegar. Consecuencias:

- Si una prueba falla, **se despliega igual**.
- Si la app nueva no arranca, **producción queda caída**.
- `latest` no dice qué versión corre ni permite volver a la anterior.
- Hay un **token de GitHub** en `config.py`, y nada lo detecta.

En el lab hay Docker propio, un registro en `localhost:5000` y Woodpecker CLI
(`ci-run` lanza el pipeline sobre el commit HEAD; `ci-logs` muestra el log).
Producción es el contenedor `api` en `127.0.0.1:8080` (`/health`).

## Objetivos

`.woodpecker.yaml` con estos steps, en este orden después de `clone`:

1. **test**: `python3 -m unittest`. Si falla, no se construye nada.
2. **scan**: `gitleaks dir .`. Si encuentra secretos, se para.
3. **build**: imagen `localhost:5000/api:<12 primeros del SHA>` (`$CI_COMMIT_SHA`).
4. **publish**: `docker push` de esa imagen.
5. **deploy**: despliega **esa** imagen como contenedor `api`, comprueba
   `/health` y, si no responde en ~20 s, **vuelve a la imagen anterior** y
   hace fallar el pipeline.

Y además: saca el token de `config.py` (léelo de la variable `GITHUB_TOKEN`).
Haz commit y deja el pipeline en verde.

El check lanzará también, sobre copias de tu repo, un commit que rompe las
pruebas (no debe publicarse nada) y otro que rompe el arranque (debe hacer
rollback y producción seguir sana).

## Pistas

```bash
cd ~/api
ci-run; ci-logs; ci-logs -l
gitleaks dir . --no-banner
curl -s localhost:5000/v2/api/tags/list
docker ps; docker inspect -f '{{.Config.Image}}' api
```

- Las variables de Woodpecker (`$CI_COMMIT_SHA`) se sustituyen en el YAML. Para
  lógica de shell (recortes, bucles) es más limpio un script en `ci/` que
  reciba la variable: `bash ci/build.sh "$CI_COMMIT_SHA"`.
- La imagen que corre ahora: `docker inspect -f '{{.Config.Image}}' api`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
