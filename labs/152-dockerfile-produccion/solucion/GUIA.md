# Resolución guiada · Lab 152

:::piensa Qué pide producción
Ligero, sin root, con healthcheck y trazable. Cada requisito del reto ataca un
problema real: tamaño, superficie de ataque, observabilidad, trazabilidad.
:::

## Paso 1 · Multi-stage con base ligera

:::pista Cómo hacerlo
```dockerfile
FROM python:3.12-slim-bookworm AS build
WORKDIR /app
COPY app.py .
RUN python -m compileall -q app.py

FROM python:3.12-slim-bookworm AS final
```
Dos `FROM`. La final solo copia lo necesario con `COPY --from=build`.
:::

## Paso 2 · Usuario no root

:::pista Cómo hacerlo
```dockerfile
RUN useradd --system --no-create-home --uid 10001 appuser
USER appuser
```
`USER` va después de copiar los ficheros (si no, el COPY se hace como root y el
proceso no podría escribir donde debe).
:::

## Paso 3 · HEALTHCHECK, labels y puerto

:::pista Cómo hacerlo
```dockerfile
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1
LABEL org.opencontainers.image.version="1.0.0"
```
:::

## Paso 4 · .dockerignore

:::pista Cómo hacerlo
`~/app/.dockerignore` con `.git`, `__pycache__/`, `*.pyc`. Acelera el build y
evita filtrar historia o cachés.
:::

## Cómo actuar en una situación así

- Base ligera + multi-stage es la mayor palanca de tamaño y CVEs.
- `runAsNonRoot` en Kubernetes rechaza imágenes sin `USER`: mejor arreglarlo aquí.

## Si te atascas

- `build falla`: `tail -20 /tmp/build152.log`.
- `User vacío` en inspect: ¿pusiste `USER appuser` en la etapa **final**?
- `Healthcheck` no detectado: debe estar en la etapa final, no en la de build.
