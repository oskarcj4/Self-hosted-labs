# Resolución guiada · Lab 91

:::piensa Evalúa lo que se va a ejecutar, no el texto
El `grep` de `admit.sh` lee el **texto** del YAML. Docker ejecuta otra cosa:
el resultado de sustituir variables (`${PRIV:-true}`), expandir `extends` y
normalizar las dos sintaxis de volúmenes. Una política que no mira lo mismo
que Docker siempre tendrá un atajo. Compose sabe darte exactamente lo que va a
ejecutar: `docker compose config`.
:::

**El plan:** (1) ver lo que Docker ve, (2) escribir la política sobre ese
JSON, (3) negar lo que no se pueda evaluar, (4) engancharla al despliegue y
(5) limpiar el stack.

## Paso 1 · Lo que Docker ve

:::pista Cómo hacerlo
```bash
cd ~/shipyard
cat fixtures/bypass-interp.yaml
docker compose -f fixtures/bypass-interp.yaml config
docker compose -f fixtures/bypass-longform.yaml config --format json | jq '.services'
```
`docker compose config` interpreta el fichero como lo haría al desplegar y
lo imprime ya resuelto; `--format json` lo da en JSON, fácil de recorrer con
`jq`.

**Qué deberías ver:** `privileged: ${PRIV:-true}` se convierte en
`"privileged": true`. Y los volúmenes, se escriban como se escriban, salen
siempre igual: `{"type": "bind", "source": "…", "target": "…"}`.
:::

## Paso 2 · La política, sobre el JSON

:::pista Cómo hacerlo
`admit.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
f="${1:?uso: ./admit.sh <compose.yaml>}"
if ! json=$(docker compose -f "$f" config --format json 2>/dev/null); then
  echo "DENY $f: no se puede evaluar (fail-closed)"; exit 1
fi
deny=$(jq -r '
  def bad_src:
    . == "/" or test("docker\\.sock$")
    or test("^/(var/run|run|proc|sys|etc|var/lib/docker)(/|$)");
  .services | to_entries[] | .key as $s | .value |
    (select(.privileged == true) | "\($s): privileged"),
    ({pid, ipc, network_mode, userns_mode} | to_entries[]
       | select(.value == "host") | "\($s): \(.key)=host"),
    (.volumes[]? | select(.type == "bind" and (.source | bad_src))
       | "\($s): bind \(.source)"),
    (.cap_add[]? | ascii_upcase | ltrimstr("CAP_")
       | select(IN("ALL", "SYS_ADMIN", "SYS_MODULE", "SYS_PTRACE"))
       | "\($s): cap_add \(.)"),
    (.security_opt[]? | select(test("unconfined")) | "\($s): \(.)")
' <<<"$json")
if [ -n "$deny" ]; then sed 's/^/DENY /' <<<"$deny"; exit 1; fi
echo "ALLOW $f"
```

| Pieza de jq | Qué hace |
|---|---|
| `def bad_src: …;` | Define una función: ¿esta ruta de origen es peligrosa? `test(…)` compara con una expresión regular; `(/\|$)` exige que la ruta termine ahí o siga con `/`, para no tomar `/etcetera` por `/etc`. |
| `.services \| to_entries[]` | Recorre los servicios como parejas `{key: nombre, value: definición}`. |
| `.key as $s` | Guarda el nombre del servicio para usarlo en los mensajes. |
| `{pid, ipc, …} \| to_entries[]` | Construye un objeto con esos cuatro campos y los recorre. |
| `.volumes[]?` | Recorre los volúmenes; el `?` evita un error si el servicio no tiene. |
| `ascii_upcase \| ltrimstr("CAP_")` | Normaliza `cap_sys_admin` y `SYS_ADMIN` a lo mismo. |
| `IN("ALL", …)` | ¿Está en esa lista? |

Cada violación produce una línea; si hay alguna, se niega. Como sólo se miran
los campos que Docker ejecuta, una variable de entorno o un comentario que
mencione `docker.sock` no da un falso positivo.
:::

## Paso 3 · Fail-closed

**Pregúntate:** si el YAML está roto y no se puede evaluar, ¿qué debe hacer
el gate?

:::pista La respuesta
Negar. Un gate que deja pasar lo que no entiende es un gate abierto: bastaría
con mandar un manifiesto que haga fallar al analizador. Eso hace el `if !
json=$(…)` del principio. Pruébalo:
```bash
for f in fixtures/*.yaml; do ./admit.sh "$f" >/dev/null 2>&1 && echo "ALLOW $f" || echo "DENY  $f"; done
```
**Qué deberías ver:** `DENY` en `bad.yaml` y en los `bypass-*`.
:::

## Paso 4 · Que el despliegue dependa del gate

:::pista Cómo hacerlo
`deploy.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./admit.sh compose.yaml
docker compose up -d --build
```
Con `set -e`, si `admit.sh` sale con error, el script para antes del `up`.
Nada de `|| true`, que lo anularía.
:::

## Paso 5 · Limpia el stack y despliega

:::pista Cómo hacerlo
Quita de `compose.yaml` el `privileged` y el montaje de `docker.sock`:
```yaml
name: shipyard
services:
  api:
    image: shop/api:1.0
    build: ./api
    ports:
      - "8080:8080"
    restart: unless-stopped
```
```bash
./deploy.sh
curl -s localhost:8080
bash /opt/lab/check.sh
```
**Qué deberías ver:** `ALLOW compose.yaml` y `api ok`. El check probará además
manifiestos ocultos, maliciosos y legítimos.
:::

## Cómo actuar en una situación así

- Una política de seguridad se evalúa sobre la forma **normalizada**
  (`docker compose config`, `kubectl … --dry-run=server`), nunca sobre el texto.
- Fail-closed siempre.
- En Kubernetes, esto mismo lo hacen Kyverno u OPA Gatekeeper como
  controladores de admisión.

## Si te atascas

- **Un bypass pasa:** mira su `docker compose config --format json` y busca en
  qué campo aparece el problema; la regla debe mirar ese campo.
- **Un manifiesto legítimo se niega:** revisa `bad_src`; probablemente una
  expresión demasiado amplia.
- **`deploy.sh` despliega aunque `admit.sh` niegue:** falta `set -e` o hay un
  `|| true`.
