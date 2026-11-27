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

## Paso 2b · `ci/changed.sh` completo

:::pista Cómo hacerlo
```bash
#!/usr/bin/env bash
set -euo pipefail
files=$(git diff --name-only "$1" "$2")
[ -n "$files" ] || exit 0
for d in services/*/; do
  s=$(basename "$d")
  rutas="services/$s"
  [ -f "$d/deps.txt" ] && rutas="$rutas $(grep -v '^\s*#' "$d/deps.txt" | sed 's:/*$::' || true)"
  for r in $rutas; do
    if grep -q -e "^$r/" -e "^$r\$" <<< "$files"; then echo "$s"; break; fi
  done
done | sort -u
```

| Pieza | Qué hace |
|---|---|
| `git diff --name-only A B` | Los ficheros que cambian entre dos commits, uno por línea (con varios commits en medio, la unión de todos). |
| `for d in services/*/` | Recorre las carpetas de servicios que existen en el árbol de trabajo: un servicio nuevo también entra. |
| `grep -v '^\s*#'` | Ignora los comentarios de `deps.txt`. |
| `sed 's:/*$::'` | Quita las `/` finales (`libs/comun/` → `libs/comun`). Usa `:` como separador porque el patrón lleva `/`. |
| `grep -q -e "^$r/" -e "^$r\$"` | ¿Algún fichero empieza por `ruta/` o es exactamente `ruta`? Con la `/` detrás, `libs/comunes2` no cuenta como `libs/comun`. `<<<` pasa la lista como entrada. |
| `break` | En cuanto una ruta coincide, el servicio está afectado: no hace falta mirar más. |
| `sort -u` | Ordena y quita duplicados. |

Pruébalo con commits que ya existen:
```bash
chmod +x ci/changed.sh
git log --oneline | head
bash ci/changed.sh HEAD~1 HEAD
```
:::

## Paso 3 · El pipeline

:::pista Cómo hacerlo
```bash
afectados=$(bash ci/changed.sh "$CI_BASE" "$CI_HEAD")
[ -z "$afectados" ] && { echo "nada que construir"; exit 0; }
for s in $afectados; do bash ci/build.sh "$s"; done
```
Ponlo en `ci/pipeline.sh` (con `#!/usr/bin/env bash` y `set -euo pipefail`
arriba), haz commit y prueba:
```bash
git add -A && git commit -m "CI: construir sólo los servicios afectados"
ci-run
bash /opt/lab/check.sh
```
`ci-run` ejecuta el pipeline como lo haría el CI, con `CI_BASE` y `CI_HEAD`.
:::

## Cómo actuar en una situación así

- La lista de dependencias debe ser **declarada** y revisada como código.
- Ante la duda (cambio en `ci/` o en la raíz que afecte a todo), construye todo:
  es preferible a no construir algo que sí cambió.
- Herramientas que hacen esto a escala: Bazel, Nx, Turborepo, Pants.

## Si te atascas

- `pagos` aparece cuando cambia `libs/comunes2`: compara con `ruta/`, no con el prefijo suelto.
- Sale vacío en el caso de libs: revisa que lees `deps.txt` sin espacios ni `/` final.
