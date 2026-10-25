# Solución — xtrace que filtra el secreto

## 1. Las tres fugas

| Fuga | Dónde | Por qué pasa |
|------|-------|--------------|
| xtrace | `set -x` y `set -euxo pipefail` | bash imprime cada comando ya expandido en stderr |
| base64 | `debug: auth=<base64 del token>` | base64 es codificación, se revierte con `base64 -d` |
| artefacto | `dist/hdr.txt` → `artifacts/` | los artefactos los descarga cualquiera con acceso al CI |

## 2. Jobs sin fugas

```bash
set -euo pipefail
: "${DEPLOY_TOKEN:?}"
printf 'Authorization: Bearer %s\n' "$DEPLOY_TOKEN" | bin/push -
echo ok > dist/ok.txt
```

Por stdin el secreto tampoco aparece en `argv` (visible para cualquiera con
`ps aux` o `/proc/<pid>/cmdline`).

## 3. Masking en el runner

```bash
mask() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "${line//"$DEPLOY_TOKEN"/***}"
  done
}
{ for job in jobs/*.sh; do bash "$job"; done; } 2>&1 | mask | tee logs/last-run.log
```

El patrón entre comillas dentro de `${var//"$pat"/…}` es literal: no hay
metacaracteres. Con `sed "s/$TOKEN/***/"` un token con `/`, `.` o `&` rompe el
filtro o enmascara de más.

## Lecciones

- Busca fugas por **salida** (log, artefactos, caché, argv), no por comando.
- `set -x` puede estar escondido: `set -eux`, `set -o xtrace`, `bash -x job.sh`,
  `SHELLOPTS=xtrace`. Si de verdad necesitas trazas, `set +x` alrededor de las
  líneas con secretos.
- El masking es defensa en profundidad, no el control: sólo reconoce el valor
  literal. base64, URL-encoding o un token partido en dos pasan intactos.
  GitHub enmascara `secrets.*` igual de literal; por eso existe `::add-mask::`
  para valores derivados.
- Rota el token: lo que llegó a un log o artefacto ya está comprometido.
