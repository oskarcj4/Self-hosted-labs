# Resolución guiada · Lab 93

:::piensa
El PR no arregló el compose: optimizó contra el escáner. Si el escáner mira
texto, cualquiera que lea el escáner sabe cómo esquivarlo. Primero arregla el
**escáner** (con tests), luego el compose.
:::

## Paso 1 · Compara texto y runtime

`docker inspect` del contenedor: imagen `shop/api` (= `latest`), `user=0`,
`privileged=true`. El YAML "tiene user:" y "no dice :latest". Las dos cosas
son ciertas y no sirven.

## Paso 2 · Escanea lo que Docker ejecuta

`docker compose -f "$f" config --format json` interpola `${API_PRIV:-true}`
y normaliza volúmenes. Si falla, `exit 1` (fail-closed).

## Paso 3 · Reglas en jq, por servicio

- Tag: coge el último segmento tras `/` (así el `:5000` del registro no
  cuenta). Fijado si es `@sha256:` o tiene `:tag` distinto de `latest`.
- Root: `.user` vacío, `root` o `0`, mirando sólo la parte antes de `:`.
- `privileged == true` y binds cuyo `source` acaba en `docker.sock`.

## Paso 4 · Tests

`./test-scan.sh` en verde. Añade tus propios casos a `tests/`: el check trae
más (segundo servicio, `user: "0:1000"`, YAML roto…).

## Paso 5 · Compose de verdad

`image: shop/api:1.2.0`, `user: "65534:65534"`, sin privileged. Luego
`docker compose up -d --build`.
