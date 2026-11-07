# Resolución guiada · Lab 160

:::piensa Del diff al grafo
"Qué cambió" lo dice git (`git diff --name-only`). "A quién afecta" lo dice el
grafo de dependencias (`deps.txt`). El pipeline sólo une las dos cosas.
:::

## Paso 1 · Qué ficheros cambiaron

:::pista Cómo hacerlo
```bash
git diff --name-only HEAD~1 HEAD
```
Ojo: con un rango `A..B` de varios commits, `git diff A B` ya da la unión.
:::

## Paso 2 · A quién afecta

:::pista Cómo hacerlo
Para cada `services/<s>/`, las rutas que le afectan son `services/<s>` más cada
línea de su `deps.txt`. Si algún fichero cambiado empieza por una de esas rutas
seguida de `/`, el servicio está afectado. Recorre `services/*/` en el commit
`head` para que los servicios nuevos cuenten.
:::

## Paso 3 · El pipeline

:::pista Cómo hacerlo
```bash
afectados=$(bash ci/changed.sh "$CI_BASE" "$CI_HEAD")
[ -z "$afectados" ] && { echo "nada que construir"; exit 0; }
for s in $afectados; do bash ci/build.sh "$s"; done
```
:::

## Cómo actuar en una situación así

- La lista de dependencias debe ser **declarada** y revisada como código.
- Ante la duda (cambio en `ci/` o en la raíz que afecte a todo), construye todo:
  es preferible a no construir algo que sí cambió.
- Herramientas que hacen esto a escala: Bazel, Nx, Turborepo, Pants.

## Si te atascas

- `pagos` aparece cuando cambia `libs/comunes2`: compara con `ruta/`, no con el prefijo suelto.
- Sale vacío en el caso de libs: revisa que lees `deps.txt` sin espacios ni `/` final.
