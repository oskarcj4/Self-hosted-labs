# Resolución guiada · Día 29

:::piensa Lo justo para funcionar, siempre igual
Una imagen de producción debe llevar **lo justo para funcionar**: ni
depuradores, ni pruebas, ni ficheros `.env`. Y debe ser **reproducible**: si la
imagen base cambia sola cuando sale otra versión de Python, nunca sabes qué
estás desplegando. Revisa el `Dockerfile` línea a línea preguntando: ¿esto hace
falta en producción?
:::

**El plan:** (1) hacer inventario, (2) fijar la base, (3) quitar la
depuración, (4) copiar sólo lo necesario y (5) reconstruir y verificar.

## Paso 1 · Inventario de problemas

**Objetivo:** ver todo lo que sobra antes de cambiar nada.

:::pista Cómo hacerlo
```bash
cd ~/reports
cat app/Dockerfile
ls -la app/
docker image inspect reports/worker:latest --format '{{json .Config.Env}} {{json .Config.ExposedPorts}}'
docker run --rm --entrypoint ls reports/worker:latest -a /app
```
- `docker image inspect --format` saca sólo los campos pedidos: las variables
  de entorno y los puertos declarados de la imagen.
- `--entrypoint ls` sustituye el programa de arranque por `ls`; lo que va
  después del nombre de la imagen son sus argumentos (`-a /app`). Así miras
  dentro sin arrancar el worker.

**Qué deberías ver:** `DEBUG=1`, el puerto `5678/tcp`, y en `/app` las carpetas
`debug/` y `tests/` y el fichero `.env.debug`, que han entrado con `COPY .`.
:::

## Paso 2 · Fija la base

**Pregúntate:** ¿qué diferencia hay entre `python:3-alpine` y
`python:3.12-alpine`?

:::pista La respuesta
`python:3-alpine` es una etiqueta que **se mueve**: hoy es 3.12, mañana 3.13.
Reconstruir la misma imagen dos veces puede dar dos Pythons distintos.
`python:3.12-alpine` fija la versión. Más estricto todavía es fijar por
**digest** (`python:3.12-alpine@sha256:…`): el contenido exacto, byte a byte.
:::

## Paso 3 · Quita la depuración

**Pregúntate:** ¿qué abre `DEBUG=1`?

:::pista La respuesta
```bash
grep -n DEBUG -A2 app/worker.py
```
Con `DEBUG=1`, el worker arranca un servidor en el `5678` que acepta a
cualquiera, sin autenticación. Sin la variable, no se activa. Y sin
depurador, `EXPOSE 5678` sobra. (`EXPOSE` sólo documenta un puerto; no lo
abre. Pero documentar un depurador en una imagen de producción invita a
publicarlo.)
:::

## Paso 4 · Copia sólo lo necesario

**Objetivo:** que en `/app` haya `worker.py` y `data/`, nada más.

:::pista Cómo hacerlo
`app/Dockerfile`:
```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY worker.py .
COPY data/ data/
CMD ["python", "-u", "worker.py"]
```
`COPY` explícito: sólo entra lo que nombras. Como red de seguridad,
`app/.dockerignore`:
```
debug/
tests/
.env*
Dockerfile
.dockerignore
```
`.dockerignore` decide qué **no** se envía al motor de Docker al hacer el
build. Si mañana alguien vuelve a escribir `COPY . /app`, lo sensible seguirá
fuera. `.env*` cubre cualquier fichero que empiece por `.env`.
:::

## Paso 5 · Reconstruye y verifica

```bash
docker compose up -d --build
docker run --rm --entrypoint ls reports/worker:latest -a /app
docker image inspect reports/worker:latest --format '{{json .Config.Env}} {{json .Config.ExposedPorts}}'
sleep 10; cat out/report.txt
docker image prune -f
bash /opt/lab/check.sh
```
- `up -d --build` reconstruye la imagen y recrea el contenedor con ella.
- El worker reescribe el informe cada 10 s: el `sleep 10` asegura que lo que
  lees lo ha escrito el contenedor nuevo.
- `image prune -f` borra la imagen vieja, que se quedó sin etiqueta (`<none>`)
  pero seguía conteniendo `.env.debug`.

**Qué deberías ver:** en `/app` sólo `data` y `worker.py`; ninguna variable
`DEBUG` ni puerto; y `pedidos=4 importe=301.25`.

## Cómo actuar en una situación así

- **Etiquetas flotantes** (`latest`, `3-alpine`) = builds no reproducibles.
- **`COPY` explícito + `.dockerignore`**: defensa en dos capas.
- **Producción ≠ desarrollo**: sin depuradores, sin pruebas, sin `.env`.
- `.env.debug` estuvo en la imagen: en un caso real, **rota** la contraseña de
  staging.

## Si te atascas

- **El worker no genera el informe:** `docker compose logs worker`. Suele ser
  que `data/` no está en `/app/data`, la ruta que lee `worker.py`.
- **Sigue apareciendo `.env.debug` en `/app`:** miras la imagen vieja.
  Comprueba que el `up` usó `--build`.
