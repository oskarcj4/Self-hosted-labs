# Resolución guiada · Lab 187

:::piensa Antes de optimizar, mide
¿Qué step tarda más? ¿Qué parte del build? `ci-logs` muestra cada step, y
`docker build --progress=plain` muestra cada capa con su tiempo y si salió
`CACHED`.
:::

## Paso 1 · El build de Docker

:::pista Qué pasa
- `COPY . .` antes de instalar: cualquier cambio en el código invalida esa
  capa y todas las siguientes, así que reinstala las dependencias.
- `--no-cache` tira la caché entera.
- Sin `.dockerignore`, los 150 MB de `datos/` y `.git` se envían al build y
  acaban dentro de la imagen.
:::

:::pista Cómo hacerlo
Copia primero `requirements.txt`, `wheels/` y `ci/instalar-deps.sh`, luego
`RUN` la instalación y, al final, `COPY app.py`. Quita `--no-cache`. Crea
`.dockerignore` con `.git`, `datos/`, `tests/` y `.deps/`.
:::

## Paso 2 · Las dependencias de los tests

:::pista Cómo hacerlo
Un script `ci/deps.sh` calcula la clave con
`cat requirements.txt wheels/*.whl | sha256sum`. Si
`/var/cache/ci/deps-<clave>` existe, lo enlaza como `.deps`. Si no, instala
en `<clave>.tmp` y lo renombra: así nunca queda una caché a medias.
:::

## Paso 3 · Comprobar que no se rompe nada

:::pista Qué probar
- Cambia `app.py` y lanza el pipeline: tiene que ser rápido.
- Añade una línea a `requirements.txt` (`asn1crypto==1.5.1`, está en `wheels/`):
  tiene que tardar otra vez, una sola vez.
- Rompe un test: tiene que salir rojo.
:::

## Cómo actuar en una situación así

- Mide la duración del pipeline como cualquier otra métrica (p50/p95) y pon una alarma si empeora.
- En runners efímeros, la caché de capas va al registro: `--cache-from`/`--cache-to type=registry`.
- Lo siguiente que conviene revisar: steps independientes en paralelo (`depends_on`) y tests que sólo corren si cambia su parte (lab 160).
