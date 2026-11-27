# Resolución guiada · Lab 94

:::piensa Busca por todas las salidas
Un pipeline tiene varias salidas: el log, los artefactos que publica y, a
veces, formas transformadas del mismo dato. Quitar el `set -x` cierra una
fuga de tres. Hay que buscar el token en todas partes, también codificado.
:::

**El plan:** (1) hacer inventario de fugas, (2) cerrarlas en los jobs,
(3) enmascarar en el runner y (4) volver a buscar.

## Paso 1 · Inventario de fugas

:::pista Cómo hacerlo
```bash
cd ~/trace-ci
cat run-ci.sh jobs/*.sh bin/push
grep -rn tclab-trace logs/ artifacts/
grep -rn "$(printf %s tclab-trace-token-do-not-log | base64)" logs/
grep -nE 'set +-[a-z]*x' jobs/*.sh run-ci.sh
```
- `printf %s … | base64` calcula cómo se ve el token en base64 (`printf %s`
  sin salto de línea, para que coincida exactamente) y el `grep` lo busca.
- La expresión `set +-[a-z]*x` encuentra `set -x` y también la `x` escondida
  en opciones juntas como `set -euxo`.

**Qué deberías ver:** tres fugas:
1. **xtrace:** con `set -x`, bash imprime cada comando **ya expandido**, con el
   valor del token dentro.
2. Una línea `debug: auth=<base64>`. Base64 no cifra: cualquiera lo
   descodifica con `base64 -d`.
3. `dist/hdr.txt` con la cabecera, y `dist/` se publica como artefacto.
:::

## Paso 2 · Cierra las fugas en los jobs

:::pista Cómo hacerlo
En los dos jobs, `set -euo pipefail` **sin** `x`. Borra la línea de debug. Y
pasa la cabecera a `bin/push` por la entrada estándar, sin escribirla en
disco. `jobs/20-deploy.sh` queda así:
```bash
#!/usr/bin/env bash
set -euo pipefail
: "${DEPLOY_TOKEN:?}"
printf 'Authorization: Bearer %s\n' "$DEPLOY_TOKEN" | bin/push -
echo ok > dist/ok.txt
```
- `: "${DEPLOY_TOKEN:?}"` para el script si la variable no existe (`:` no hace
  nada; sólo fuerza a evaluar la expresión).
- `bin/push -`: el `-` es la convención para "lee de la entrada". La cabecera
  pasa por una tubería: no queda en `dist/`, ni en el log, ni en la línea de
  comandos (que cualquier usuario ve con `ps`).
:::

## Paso 3 · Enmascara en el runner

**Pregúntate:** si mañana alguien añade un job que hace `echo $DEPLOY_TOKEN`,
¿qué lo protege?

:::pista Cómo hacerlo
Que el runner filtre **toda** la salida de los jobs antes de escribirla. En
`run-ci.sh`, define:
```bash
mask() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "${line//"$DEPLOY_TOKEN"/***}"
  done
}
```
y pasa por ella el bloque que ejecuta los jobs:
```bash
{
  echo "=== ci $(date -Iseconds) ==="
  for job in jobs/*.sh; do
    echo "--- $job"
    bash "$job"
  done
} 2>&1 | mask | tee logs/last-run.log
```

| Pieza | Qué hace |
|---|---|
| `while IFS= read -r line` | Lee línea a línea. `IFS=` conserva los espacios del principio; `-r` no interpreta las `\`. |
| `\|\| [ -n "$line" ]` | Procesa también la última línea aunque no termine en salto de línea. |
| `${line//"$DEPLOY_TOKEN"/***}` | Sustituye todas (`//`) las apariciones del token por `***`. Con el token **entre comillas**, la comparación es literal. |
| `2>&1` | Junta los errores con la salida normal, para que también pasen por `mask`. |

¿Por qué no `sed "s/$DEPLOY_TOKEN/***/"`? Porque `sed` interpreta el token como
expresión regular: un `.` en el token encajaría con cualquier carácter, y un
`/` rompería la orden.
:::

## Paso 4 · Ejecuta y busca otra vez

```bash
./run-ci.sh
grep -rn tclab-trace logs/ artifacts/
grep -rn "$(printf %s tclab-trace-token-do-not-log | base64)" logs/
grep -nE 'set +-[a-z]*x' jobs/*.sh run-ci.sh
ls artifacts/
bash /opt/lab/check.sh
```
**Qué deberías ver:** `push ok` en la salida, `ok.txt` en `artifacts/` y los
tres `grep` sin resultados.

## Cómo actuar en una situación así

- Los sistemas de CI enmascaran los secretos que conocen, pero sólo su valor
  literal: un base64, un trozo o un `rev` del token pasan.
- Nunca publiques como artefacto una carpeta donde se escriben credenciales.
- El token salió en logs y artefactos: en un caso real, **rótalo**.

## Si te atascas

- **El check encuentra el token en el log:** queda un `set -x` (o una `x` en
  `set -euxo`), o la línea de debug.
- **`push` falla:** `bin/push -` espera la cabecera en la entrada; comprueba
  la tubería.
- **Sale `***` donde no debería:** el token está vacío y la sustitución
  reemplaza "nada". Asegúrate de cargar `secrets/deploy_token` antes de `mask`.
