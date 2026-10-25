# Resolución guiada · Lab 94

:::piensa
Busca el token por **todas** las salidas del pipeline: log, artefactos y
formas transformadas. Quitar `set -x` arregla una fuga de tres.
:::

## Paso 1 · Inventario de fugas

```bash
grep -rn tclab-trace logs/ artifacts/
grep -rn "$(printf %s tclab-trace-token-do-not-log | base64)" logs/
grep -nE 'set +-[a-z]*x' jobs/*.sh run-ci.sh
```

Tres fugas: xtrace (`set -x` y el `x` escondido en `set -euxo`), la línea
`debug: auth=<base64>` y `dist/hdr.txt` publicado como artefacto.

## Paso 2 · Quita las fugas en los jobs

- `set -euo pipefail` sin `x` en los dos jobs.
- Borra la línea de debug en base64.
- `printf 'Authorization: Bearer %s\n' "$DEPLOY_TOKEN" | bin/push -`:
  la cabecera no toca disco.

## Paso 3 · Enmascara en el runner

Filtra toda la salida antes de `tee`. Usa sustitución **literal** de bash,
no `sed` (un `/` o `.` en el token rompe o amplía la regex):

```bash
mask() { while IFS= read -r l || [ -n "$l" ]; do printf '%s\n' "${l//"$DEPLOY_TOKEN"/***}"; done; }
{ ...jobs... } 2>&1 | mask | tee logs/last-run.log
```

## Paso 4 · Ejecuta y busca otra vez

`./run-ci.sh` y repite los `grep` del paso 1: ninguno debe encontrar nada.
