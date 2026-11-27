# Resolución guiada · Lab 95

:::piensa Restar, no improvisar
Un programa habla con el kernel mediante **syscalls** (llamadas al sistema:
abrir un fichero, crear un proceso, leer la memoria de otro proceso…).
**seccomp** es un filtro del kernel que decide qué syscalls puede hacer un
proceso. `unconfined` quita el filtro. El perfil por defecto de Docker está
pensado para que arranque *cualquier* imagen, así que permite cosas que tu
API no necesita. La forma segura es partir de ese perfil y **quitar**, no
escribir uno desde cero.
:::

**El plan:** (1) medir, (2) encontrar las syscalls en el perfil,
(3) generar el perfil propio, (4) aplicarlo y (5) comprobar.

## Paso 1 · Mide

:::pista Cómo hacerlo
```bash
cd ~/seccomp
cat compose.yaml probe.sh
./probe.sh
```
`probe.sh` entra en el contenedor y prueba tres cosas: cuántos filtros seccomp
tiene el proceso (`Seccomp_filters` en `/proc/self/status`) y si puede usar
`ptrace` y `process_vm_readv`.

**Qué deberías ver:** los mismos filtros que el host y las dos syscalls
permitidas. `ptrace` es lo que usan los depuradores para controlar otro
proceso; `process_vm_readv`/`writev`, para leer o escribir su memoria.
:::

## Paso 2 · Las reglas del perfil de Docker

:::pista Cómo hacerlo
```bash
jq '.defaultAction, (.syscalls | length)' profiles/docker-default.json
jq '.syscalls[] | select(.names | index("ptrace"))' profiles/docker-default.json
```
Un perfil seccomp es un JSON:
- `defaultAction`: qué hacer con las syscalls no listadas. `SCMP_ACT_ERRNO` =
  denegar (devuelven error). Es una **lista blanca**.
- `syscalls`: una lista de reglas; cada una con `names` (las syscalls) y
  `action` (`SCMP_ACT_ALLOW` = permitir), a veces con condiciones.

`select(.names | index("ptrace"))` filtra las reglas cuya lista `names`
contiene `ptrace`.

**Qué deberías ver:** `ptrace` aparece en **dos** reglas (una condicionada a
la versión del kernel, otra a la capability `CAP_SYS_PTRACE`). Hay que
quitarla de todas.
:::

## Paso 3 · Genera tu perfil

:::pista Cómo hacerlo
```bash
jq '.syscalls |= (map(.names -= ["ptrace","process_vm_readv","process_vm_writev"])
                  | map(select(.names | length > 0)))' \
  profiles/docker-default.json > profiles/api.json
jq '.syscalls[] | select(.names | index("ptrace"))' profiles/api.json
```

| Pieza | Qué hace |
|---|---|
| `.syscalls \|= (…)` | Sustituye la lista de reglas por el resultado de lo de dentro. |
| `map(.names -= [...])` | A cada regla le quita esas tres syscalls de su lista. |
| `map(select(.names \| length > 0))` | Descarta las reglas que se hayan quedado vacías. |

El `defaultAction` no se toca: sigue denegando todo lo que no está permitido.

**Qué deberías ver:** la segunda consulta no imprime nada.
:::

## Paso 4 · Aplícalo

:::pista Cómo hacerlo
En `compose.yaml`, sustituye `seccomp:unconfined` por tu perfil:
```yaml
    security_opt:
      - seccomp=./profiles/api.json
```
```bash
docker compose up -d --force-recreate
```
`--force-recreate` recrea el contenedor aunque Compose no detecte cambios: el
perfil se aplica al **crear** el contenedor.
:::

## Paso 5 · Comprueba

```bash
./probe.sh
curl -s localhost:8080
bash /opt/lab/check.sh
```
**Qué deberías ver:** un filtro seccomp más que el host, `ptrace` y
`process_vm_readv` con `Operation not permitted`, y `api ok`: la API no las
necesitaba.

## Cómo actuar en una situación así

- `seccomp:unconfined` "porque algo petaba" se revisa: averigua qué syscall
  era y permite **esa**.
- Para saber qué syscalls usa realmente una app: `strace -f -c` en pruebas, o
  herramientas que generan el perfil a partir de una ejecución.
- seccomp se combina con capabilities (lab 89) y `no-new-privileges`: capas
  distintas.

## Si te atascas

- **El contenedor no arranca tras aplicar el perfil:** el JSON está mal o le
  quitaste algo que sí necesita. `docker compose logs api` y `jq . profiles/api.json`.
- **`probe.sh` sigue igual:** el contenedor no se recreó; usa `--force-recreate`.
- **Docker no encuentra el perfil:** la ruta es relativa a la carpeta del
  `compose.yaml` (`./profiles/api.json`).
