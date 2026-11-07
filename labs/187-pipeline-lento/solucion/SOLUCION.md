# Solución — Pipeline lento

## Dónde se iba el tiempo

| Causa | Coste por commit | Arreglo |
|-------|------------------|---------|
| step `deps` reinstala siempre | ~20 s | caché en `/var/cache/ci/deps-<hash>` |
| `COPY . .` antes de instalar | ~20 s | copiar primero lo que define las dependencias |
| `--no-cache` | todas las capas | quitarlo |
| `datos/` y `.git` en el contexto | 150 MB enviados y metidos en la imagen | `.dockerignore` |

## Dockerfile

```dockerfile
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY requirements.txt ./
COPY wheels/ wheels/
COPY ci/instalar-deps.sh ci/
RUN bash ci/instalar-deps.sh && rm -rf wheels
COPY app.py ./
USER 10001
CMD ["python", "app.py"]
```

`ci/deps.sh` y el `.woodpecker.yaml` completos están en `solve.sh`.

## Por qué la clave es el hash

Una caché "por nombre" (`/var/cache/ci/deps`) nunca sabe cuándo está
obsoleta. Con el hash de `requirements.txt` y los wheels, un cambio genera
otra clave y la instalación se repite una sola vez. Es la misma idea que
`actions/cache` con `key: ${{ hashFiles('requirements.txt') }}`.

## Más allá del lab

- `RUN --mount=type=cache,target=/root/.cache/pip`: la caché de pip persiste entre builds aunque se invalide la capa.
- Imagen base de CI con las herramientas ya instaladas.
- `--cache-from` y `--cache-to` al registro para runners sin estado.
