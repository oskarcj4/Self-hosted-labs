# Monorepo: construir sólo lo que cambió

> CI/CD · monorepo · git diff · grafo de dependencias · builds selectivos

## Escenario

`~/monorepo` tiene tres servicios (`services/catalogo`, `services/pagos`,
`services/notificaciones`) y una librería compartida (`libs/comun`). El
pipeline (`ci/pipeline.sh`) **construye y redespliega los tres en cada push**,
aunque sólo cambie un README. Con 3 servicios es lento; con 40 es inviable, y
además redesplegar lo que no cambió es riesgo gratis.

Cada servicio declara de qué rutas depende en `services/<s>/deps.txt`
(`catalogo` y `pagos` dependen de `libs/comun`; `notificaciones` de nada).

`ci-run` ejecuta el pipeline como el CI: `CI_BASE` = commit anterior,
`CI_HEAD` = HEAD.

## Objetivos

1. `ci/changed.sh <base> <head>`: imprime los servicios afectados, uno por
   línea, ordenados y sin repetir:
   - cambio en `services/<s>/…` → `<s>`
   - cambio en una ruta de `services/<s>/deps.txt` → `<s>`
   - `docs/`, `README.md`… → nada
   - un servicio nuevo en `services/` también cuenta
2. `ci/pipeline.sh` construye **sólo** lo que diga `ci/changed.sh "$CI_BASE" "$CI_HEAD"`;
   si no hay nada, termina con éxito sin construir.
3. Commit de los cambios.

## Pistas

```bash
cd ~/monorepo
ci-run                                   # hoy: 3 builds para un cambio en docs
git diff --name-only HEAD~1 HEAD
git diff --name-only HEAD~1 HEAD | cut -d/ -f1-2 | sort -u
cat services/*/deps.txt
```

Esqueleto:
```bash
#!/usr/bin/env bash
set -euo pipefail
files=$(git diff --name-only "$1" "$2")
for d in services/*/; do
  s=$(basename "$d")
  # ¿algún fichero empieza por services/$s/ o por una ruta de su deps.txt?
done | sort -u
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
