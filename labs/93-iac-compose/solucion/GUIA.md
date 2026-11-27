# Resolución guiada · Lab 93

:::piensa Si el escáner mira texto, se esquiva leyendo el escáner
El PR #301 no arregló el `compose.yaml`: aprendió a esquivar el `grep` del
escáner. Un escáner que busca texto falla en las dos direcciones: no ve lo que
está escrito de otra forma (**falsos negativos**) y salta con lo que sólo se
menciona, como un comentario (**falsos positivos**). Primero se arregla el
escáner, con tests que lo demuestren; después, el compose.
:::

**El plan:** (1) comparar el texto con lo que corre, (2) escanear lo que
Docker ejecuta, (3) escribir las reglas, (4) pasar los tests y (5) arreglar el
compose.

## Paso 1 · Texto frente a realidad

:::pista Cómo hacerlo
```bash
cd ~/iac
cat compose.yaml scan.sh
docker inspect -f '{{.Config.Image}} user={{.Config.User}} priv={{.HostConfig.Privileged}}' \
  $(docker compose ps -q api)
./scan.sh
```
**Qué deberías ver:** el escáner dice "limpio", pero el contenedor corre con
la imagen `shop/api` (sin tag = `latest`), `user=0` y `privileged=true`. El YAML
"tiene un `user:`" y "no dice `:latest`": ambas cosas son ciertas y no sirven.
:::

## Paso 2 · Escanea lo que Docker ejecuta

:::pista Cómo hacerlo
```bash
docker compose -f compose.yaml config --format json | jq '.services.api'
```
`docker compose config` resuelve el fichero como al desplegar: sustituye
variables (`${API_PRIV:-true}` → `true`) y normaliza los volúmenes. Ése es el
JSON que hay que evaluar. Si no se puede generar (YAML roto), el escáner
**falla**: un escáner que da "limpio" a lo que no entiende está abierto.
:::

## Paso 3 · Las reglas

:::pista Cómo hacerlo
`scan.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
f="${1:-compose.yaml}"
if ! json=$(docker compose -f "$f" config --format json 2>/dev/null); then
  echo "HIGH: $f no se puede evaluar (fail-closed)"; exit 1
fi
hits=$(jq -r '
  .services | to_entries[] | .key as $s | .value |
    ((.image // "") as $img | ($img | split("/") | last) as $last
      | if ($img | test("@sha256:[0-9a-f]{64}$")) then empty
        elif ($last | test(":")) and ($last | test(":latest$") | not) then empty
        else "\($s): imagen sin tag fijo (\($img))" end),
    ((.user // "root") | tostring | split(":")[0]
      | select(. == "" or . == "root" or . == "0") | "\($s): corre como root"),
    (select(.privileged == true) | "\($s): privileged"),
    (.volumes[]? | select(.type == "bind" and (.source | test("docker\\.sock$")))
      | "\($s): monta docker.sock")
' <<<"$json")
if [ -n "$hits" ]; then sed 's/^/HIGH: /' <<<"$hits"; exit 1; fi
echo "scan: limpio"
```

| Regla | Cómo lo resuelve |
|---|---|
| Tag fijo | `split("/") \| last` se queda con el último trozo de la imagen. En `registro:5000/app`, el `:5000` es un puerto y queda fuera; en `app:1.2`, el `:` sí es un tag. Un digest `@sha256:` de 64 caracteres también cuenta como fijado. `empty` = no hay hallazgo. |
| Root | `.user // "root"`: si no hay `user`, es root. `split(":")[0]` mira sólo el usuario de `usuario:grupo`, así `"0:1000"` también es root. `tostring` por si es un número. |
| privileged | Sobre el valor ya interpolado: `${VAR:-true}` llega como `true`. |
| docker.sock | Sólo en volúmenes de tipo `bind`, en el origen: una variable de entorno que lo mencione no es un montaje. |
:::

## Paso 4 · Los tests

```bash
./test-scan.sh
ls tests/deny tests/allow
```
`test-scan.sh` pasa el escáner por `tests/deny/` (deben fallar) y
`tests/allow/` (deben pasar). Añade tus propios casos (un segundo servicio,
`user: "0:1000"`, una imagen con registro y puerto, un YAML roto): el check
trae más de los que ves.

## Paso 5 · El compose, de verdad

:::pista Cómo hacerlo
```yaml
name: iac
services:
  api:
    image: shop/api:1.2.0
    build: ./api
    user: "65534:65534"
    ports:
      - "8080:8080"
    restart: unless-stopped
```
```bash
./scan.sh
docker compose up -d --build
curl -s localhost:8080
bash /opt/lab/check.sh
```
`65534` es el UID de `nobody`, un usuario sin privilegios que existe en casi
todas las imágenes.
:::

## Cómo actuar en una situación así

- Un escáner sin tests es una opinión. Cada bypass encontrado se convierte en
  un caso de `tests/deny/`.
- Revisa los PR que "arreglan" un escáner cambiando el formato del fichero en
  vez del contenido.
- En la vida real: Checkov, trivy config o KICS, que ya evalúan la forma
  normalizada.

## Si te atascas

- **Un caso legítimo sale como hallazgo:** probablemente la regla del tag no
  separa bien el registro (`split("/") | last`).
- **`test-scan.sh` dice que un `deny` pasa:** mira su `config --format json` y
  qué campo tiene el problema.
- **`./scan.sh` dice limpio pero el contenedor sigue igual:** falta
  `docker compose up -d --build`.
