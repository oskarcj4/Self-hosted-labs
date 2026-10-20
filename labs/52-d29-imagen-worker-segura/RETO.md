# Día 29 — Endurecer la imagen de un worker

> 30 días de DevSecOps · Docker · Endurecimiento de imágenes

## Escenario

La imagen de `reports-worker` (`~/reports`) se construyó "como en el portátil":

- `FROM python:3-alpine`: la base cambia sola cuando sale otra versión de Python.
- `ENV DEBUG=1`: el worker abre un **depurador remoto sin autenticación** en `:5678`.
- `EXPOSE 5678`.
- `COPY . /app`: dentro van `debug/` (una shell remota), `tests/` y
  `.env.debug` (con la contraseña de la base de datos de staging).

```bash
docker compose exec worker ls -a /app
docker compose exec worker cat /app/.env.debug
```

## Objetivos

1. Imagen base **fijada**: `python:3.12-alpine` (o por digest `@sha256:…`).
2. La imagen no define `DEBUG` ni expone `5678`; el depurador no está activo.
3. La imagen sólo lleva lo necesario: `worker.py` y `data/` (nada de `debug/`,
   `tests/`, `.env*`, `Dockerfile`).
4. El worker, ya reconstruido, sigue generando `out/report.txt` →
   `pedidos=4 importe=301.25`.

## Comandos que te pueden servir

```bash
cd ~/reports && cat app/Dockerfile ; ls -la app/
docker image inspect reports/worker:latest --format '{{json .Config.Env}} {{json .Config.ExposedPorts}}'
docker compose up -d --build
docker run --rm --entrypoint ls reports/worker:latest -a /app
cat out/report.txt
```

> Pistas: `.dockerignore`, y `COPY` explícito de lo que hace falta.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
