# Solución — Monorepo: construir sólo lo que cambió

`ci/changed.sh`:
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

`ci/pipeline.sh`:
```bash
afectados=$(bash ci/changed.sh "$CI_BASE" "$CI_HEAD")
[ -z "$afectados" ] && { echo "Nada que construir"; exit 0; }
for s in $afectados; do bash ci/build.sh "$s"; done
```

| Cambio | Afectados |
|--------|-----------|
| `services/pagos/app.py` | pagos |
| `libs/comun/util.py` | catalogo, pagos |
| `docs/…`, `README.md` | — |
| servicio nuevo `services/envios/` | envios |

## Por qué

- Construir todo en cada push escala con el número de servicios, no con el
  tamaño del cambio. Con selección, el coste es proporcional a lo tocado.
- Redesplegar lo que no cambió no aporta nada y añade riesgo (y ruido en alertas).
- La dependencia `libs/comun` es la trampa clásica: si sólo miras la carpeta del
  servicio, un cambio en la librería no despliega a nadie.

## Más allá del lab

- Cambios en `ci/` o en ficheros raíz (lockfiles, Dockerfile base) → construir todo.
- Bazel/Nx calculan el grafo a partir de los imports, no de un fichero a mano.
- En GitHub Actions: `paths:` por workflow o `dorny/paths-filter`.
