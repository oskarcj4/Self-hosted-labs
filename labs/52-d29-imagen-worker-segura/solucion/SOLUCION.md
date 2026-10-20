# Solución — Día 29: Endurecer la imagen de un worker

## 1. Inventario de problemas

```bash
cd ~/reports
docker image inspect reports/worker:latest --format '{{json .Config.Env}}'          # DEBUG=1
docker image inspect reports/worker:latest --format '{{json .Config.ExposedPorts}}' # 5678
docker compose exec worker ls -a /app       # .env.debug debug tests Dockerfile ...
docker compose exec worker nc -z 127.0.0.1 5678 && echo "depurador abierto"
```

## 2. Dockerfile de producción

```dockerfile
FROM python:3.12-alpine
ENV PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY worker.py .
COPY data/ data/
CMD ["python", "-u", "worker.py"]
```

- Base fijada a `3.12` (aún más estricto: `python:3.12-alpine@sha256:<digest>`,
  que obtienes con `docker image inspect python:3.12-alpine --format '{{index .RepoDigests 0}}'`).
- Sin `DEBUG`, sin `EXPOSE 5678`.
- `COPY` explícito: sólo entra lo que el worker usa.

## 3. `.dockerignore` (defensa en profundidad)

```
debug/
tests/
.env*
Dockerfile
.dockerignore
```

Así, aunque alguien vuelva a escribir `COPY . /app`, los secretos y utilidades
no viajan al contexto de build.

## 4. Reconstruir y verificar

```bash
docker compose up -d --build
docker run --rm --entrypoint ls reports/worker:latest -a /app   # data  worker.py
docker image inspect reports/worker:latest --format '{{json .Config.Env}}'   # sin DEBUG
sleep 2; cat out/report.txt                                      # pedidos=4 importe=301.25
docker image prune -f                                            # borra la imagen vieja
```

## Lecciones

- Etiquetas flotantes (`3-alpine`, `latest`) = builds no reproducibles y cambios sin revisar.
- Imagen de producción ≠ entorno de desarrollo: nada de depuradores, pruebas ni `.env`.
- `COPY . .` sin `.dockerignore` mete en la imagen todo lo que haya en la carpeta (incluido `.git`).
- `.env.debug` estuvo en la imagen: en un caso real, rotar la contraseña de staging.
